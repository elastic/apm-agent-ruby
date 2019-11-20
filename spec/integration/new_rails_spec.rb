# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  enabled = true
else
  puts '[INFO] Skipping Rails spec'
end

if enabled
  require 'action_controller/railtie'
  require 'action_mailer/railtie'

  RSpec.describe 'Rails integration' do
    include Rack::Test::Methods
    include_context 'request_parser'

    def app
      @app ||= Rails.application
    end

    after :all do
      ElasticAPM.stop
      ElasticAPM::Transport::Worker.adapter = nil
    end

    before :all do
      module RailsTestApp
        class Application < Rails::Application
          config.secret_key_base = '__secret_key_base'
          config.consider_all_requests_local = false
          config.eager_load = false

          config.elastic_apm.ignore_url_patterns = '/ping'
          config.elastic_apm.api_request_time = '200ms'
          config.elastic_apm.disable_start_message = true

          # Silence deprecation warning
          if defined?(ActionView::Railtie::NULL_OPTION)
            config.action_view.finalize_compiled_template_methods =
                ActionView::Railtie::NULL_OPTION
          end
          config.elastic_apm.capture_body = 'all'
          config.elastic_apm.pool_size = Concurrent.processor_count

          config.elastic_apm.log_path = 'spec/elastic_apm.log'
        end
      end

      class ApplicationController < ActionController::Base

        before_action do
          ElasticAPM.set_user(current_user)
        end

        http_basic_authenticate_with(
          name: 'dhh', password: 'secret123', only: [:create]
        )

        def index
          render_ok
        end

        def context
          ElasticAPM.set_label :things, 1
          ElasticAPM.set_custom_context nested: { banana: 'explosion' }
          render_ok
        end

        def create
          render_ok
        end

        private

        def render_ok
          if Rails.version.start_with?('4')
            render text: 'Yes!'
          else
            render plain: 'Yes!'
          end
        end

        User = Struct.new(:id, :email)

        def current_user
          @current_user ||= User.new(1, 'person@example.com')
        end
      end

      class TestAdapter < ElasticAPM::Transport::Connection
        def write(payload)
          RequestParser.catalog(JSON.parse(@metadata))
          RequestParser.catalog JSON.parse(payload)
        end
      end

      ElasticAPM::Transport::Worker.adapter = TestAdapter

      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        root to: 'application#index'
        get '/tags_and_context', to: 'application#context'
        post '/', to: 'application#create'
      end
    end

    context 'Service metadata', :allow_running_agent do
      it 'includes Rails info' do
        responses = Array.new(10).map { get '/' }

        RequestParser.wait_for transactions: 10, spans: 20, timeout: 10

        expect(responses.last.body).to eq 'Yes!'
        expect(RequestParser.metadatas.length >= 1).to be true
        expect(RequestParser.transactions.length).to be 10

        service = RequestParser.metadatas.fetch(0)['service']
        expect(service['name']).to eq 'RailsTestApp'
        expect(service['framework']['name']).to eq 'Ruby on Rails'
        expect(service['framework']['version'])
            .to match(/\d+\.\d+\.\d+(\.\d+)?/)
      end
    end

    context 'log path', :allow_running_agent do
      it 'prepends Rails.root to log_path' do
        final_log_path = ElasticAPM.agent.config.log_path.to_s
        expect(final_log_path).to eq "#{Rails.root}/spec/elastic_apm.log"
      end
    end

    describe 'transactions' do
      context 'when a simple request is made', :allow_running_agent do
        it 'spans action and posts it' do
          get '/'

          RequestParser.wait_for transactions: 1, spans: 2

          name = RequestParser.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#index'
        end
      end

      context 'when tags and context are set', :allow_running_agent do
        it 'sets the values' do
          get '/tags_and_context'

          RequestParser.wait_for transactions: 1, spans: 2

          context = RequestParser.transactions.fetch(0)['context']
          expect(context['tags']).to eq('things' => 1)
          expect(context['custom']).to eq('nested' => {'banana' => 'explosion'})
        end
      end

      context 'when there is user information', :allow_running_agent do
        it 'includes the info in transactions' do
          get '/'

          RequestParser.wait_for transactions: 1, spans: 2

          context = RequestParser.transactions.fetch(0)['context']
          user = context['user']
          expect(user['id']).to eq '1'
          expect(user['email']).to eq 'person@example.com'
        end
      end

      context 'when there are ignored url patterns defined', :allow_running_agent do
        it 'does not create events for the patterns' do
          get '/ping'
          get '/'

          RequestParser.wait_for transactions: 1, spans: 2

          name = RequestParser.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#index'
        end
      end

      context 'when there is sensitive data', :allow_running_agent do
        it 'filters the data and does not alter the original' do
          resp = post '/', access_token: 'abc123'

          RequestParser.wait_for transactions: 1, spans: 1

          expect(resp.body).to eq("HTTP Basic: Access denied.\n")
          expect(resp.original_headers['WWW-Authenticate']).to_not be nil
          expect(resp.original_headers['WWW-Authenticate']).to_not eq '[FILTERED]'

          transaction, = RequestParser.transactions

          body = transaction.dig('context', 'request', 'body')
          expect(body['access_token']).to eq '[FILTERED]'

          response_headers = transaction.dig('context', 'response', 'headers')
          expect(response_headers['WWW-Authenticate']).to eq '[FILTERED]'
        end
      end

      context 'when json', :allow_running_agent do
        it 'the schema is validated', type: :json_schema do
          get '/'

          RequestParser.wait_for transactions: 1

          metadata = RequestParser.metadatas.fetch(0)
          expect(metadata).to match_json_schema(:metadatas),
                              metadata.inspect

          transaction = RequestParser.transactions.fetch(0)
          expect(transaction).to match_json_schema(:transactions),
                                 transaction.inspect

          span = RequestParser.spans.fetch(0)
          expect(span).to match_json_schema(:spans),
                          span.inspect
        end
      end
    end
  end
end
