# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  enabled = true
else
  puts '[INFO] Skipping Rails spec'
end


if enabled
  require 'active_record'
  require 'action_controller/railtie'
  require 'graphql'

  RSpec.describe 'GraphQL', :allow_running_agent, :spec_logger, :mock_intake do
    include Rack::Test::Methods

    def setup_database
      ActiveRecord::Base.logger = Logger.new(SpecLogger)

      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: '/tmp/bench.sqlite3'
      )

      ActiveRecord::Schema.define do
        create_table :posts, force: true do |t|
          t.string :slug, null: false
          t.string :title, null: false
          t.timestamps
        end

        create_table :comments, force: true do |t|
          t.text :body, null: false
          t.belongs_to :post, null: false, index: true
          t.timestamps
        end
      end

      a = Post.create!(slug: 'a', title: 'A')
      Post.create!(slug: 'b', title: 'B')
      Post.create!(slug: 'c', title: 'C')
      Comment.create!(post: a, body: 'So good')
    end

    let(:app) { Rails.application }

    before :all do
      module Types
        class CommentType < GraphQL::Schema::Object
          field :body, String, null: false
        end

        class PostType < GraphQL::Schema::Object
          field :slug, String, null: false
          field :title, String, null: false
          field :comments, [CommentType], null: false
        end

        class QueryType < GraphQL::Schema::Object
          field :posts, [PostType], null: false
          field :post, PostType, null: false do
            argument :slug, String, required: true
          end

          def posts
            Post.all
          end

          def post(slug:)
            Post.find_by(slug: slug)
          end
        end

        class GraphQLTestAppSchema < GraphQL::Schema
          query QueryType

          use GraphQL::Execution::Interpreter
          use GraphQL::Analysis::AST
        end
      end

      class Post < ActiveRecord::Base
        has_many :comments
      end

      class Comment < ActiveRecord::Base
        belongs_to :post
      end

      setup_database

      module GraphQLTestApp
        class Application < Rails::Application
          configure_rails_for_test

          config.elastic_apm.disable_metrics = '*'
          config.elastic_apm.api_request_time = '200ms'
          config.logger = Logger.new(SpecLogger)
        end
      end

      # rubocop:disable Style/ClassAndModuleChildren
      class ::ApplicationController < ActionController::Base
        def index
          render plain: 'ok'
        end
      end

      class ::GraphqlController < ApplicationController
        def execute
          variables = params[:variables]
          query = params[:query]
          operation_name = params[:operationName]
          context = {
            # Query context goes here, for example:
            # current_user: current_user,
          }
          result = Types::GraphQLTestAppSchema.execute(
            query,
            variables: variables,
            context: context,
            operation_name: operation_name
          )

          render json: result
        rescue => e
          logger.error e.message
          # logger.error e.backtrace.join("\n")

          render(
            status: 500,
            json: {
              error: { message: e.message, backtrace: e.backtrace },
              data: {}
            }
          )
        end
      end
      # rubocop:enable Style/ClassAndModuleChildren

      MockIntake.stub!

      GraphQLTestApp::Application.initialize!
      GraphQLTestApp::Application.routes.draw do
        post "/graphql", to: "graphql#execute"
        root to: 'application#index'
      end
    end

    after :all do
      ElasticAPM.stop
    end

    it "doesn't start when console" do
      resp = post '/graphql', query: """
        {
          posts {
            title
            comments { body }
          }
        }
      """

      wait_for transactions: 1

      expect(resp.status).to be 200
      pp JSON.parse(resp.body)

      pp @mock_intake.transactions
      pp @mock_intake.spans
    end
  end
end
