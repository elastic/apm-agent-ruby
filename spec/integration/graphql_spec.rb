# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'integration_helper'

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
      ActiveRecord::Base.logger = Logger.new(nil)

      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: '/tmp/graphql.sqlite3'
      )

      ActiveRecord::Migration.suppress_messages do
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
            Post.where(slug: slug).first!
          end
        end

        class GraphQLTestAppSchema < GraphQL::Schema
          query QueryType
          tracer ElasticAPM::GraphQL
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
          RailsTestHelpers.setup_rails_test_config(config)

          config.elastic_apm.disable_metrics = '*'
          config.elastic_apm.api_request_time = '200ms'
          config.logger = Logger.new(SpecLogger)
          # config.logger = Logger.new(nil)
        end
      end

      class ::ApplicationController < ActionController::Base
        def index
          render plain: 'ok'
        end
      end

      class ::GraphqlController < ApplicationController
        def execute
          context_ = {}

          result =
            if (multi = params[:multi])
              Types::GraphQLTestAppSchema.multiplex(
                multi.map do |q|
                  { query: q[:query], variables: q[:variables], context: context_ }
                end
              )
            else
              Types::GraphQLTestAppSchema.execute(
                params[:query],
                variables: params[:variables],
                context: context_,
                operation_name: params[:operation_name]
              )
            end

          render json: result
        rescue StandardError => e
          logger.error e.message

          render(
            status: 500,
            json: { error: { message: e.message }, data: {} }
          )
        end
      end

      MockIntake.stub!

      GraphQLTestApp::Application.initialize!
      GraphQLTestApp::Application.routes.draw do
        post '/graphql', to: 'graphql#execute'
        root to: 'application#index'
      end
    end

    after :all do
      ElasticAPM.stop
    end

    context 'a query with an Operation Name' do
      it 'adds spans and renames transaction' do
        resp = post '/graphql', query: '
          query PostsWithComments {
            posts {
              title
              comments { body }
            }
          }
        '

        wait_for transactions: 1, spans: 13

        expect(resp.status).to be 200

        transaction, = @mock_intake.transactions
        expect(transaction['name']).to eq 'GraphQL: PostsWithComments'
      end
    end

    context 'with an unnamed query' do
      it 'renames to [unnamed]' do
        resp = post '/graphql', query: '{ posts { title } }'

        wait_for transactions: 1

        expect(resp.status).to be 200

        transaction, = @mock_intake.transactions
        expect(transaction['name']).to eq 'GraphQL: [unnamed]'
      end
    end

    context 'with multiple queries' do
      it 'renames and concattenates' do
        resp = post '/graphql', multi: [
          { query: 'query Posts { posts { title } }' },
          { query: 'query PostA($slug: String!) { post(slug: $slug) { title } }', variables: { slug: 'a' } }
        ]

        wait_for transactions: 1

        expect(resp.status).to be 200

        transaction, = @mock_intake.transactions
        expect(transaction['name']).to eq 'GraphQL: Posts+PostA'
      end
    end

    context 'with too many queries to list' do
      it 'renames and concattenates' do
        resp = post '/graphql', multi: [
          { query: 'query Posts { posts { title } }' },
          { query: 'query PostsWithComments { posts { title comments { body } } }' },
          { query: 'query PostA($a: String!) { post(slug: $a) { title } }', variables: { a: 'a' } },
          { query: 'query PostB($b: String!) { post(slug: $b) { title } }', variables: { b: 'b' } },
          { query: 'query PostC($c: String!) { post(slug: $c) { title } }', variables: { c: 'c' } },
          { query: 'query MorePosts { posts { title } }' }
        ]

        wait_for transactions: 1

        expect(resp.status).to be 200

        transaction, = @mock_intake.transactions
        expect(transaction['name']).to eq 'GraphQL: [multiple-queries]'
      end
    end
  end
end
