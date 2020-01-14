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

  RSpec.describe 'Rails integration', :allow_running_agent, :spec_logger do
    include Rack::Test::Methods
    include_context 'event_collector'

    let(:app) do
      Rails.application
    end

    after :all do
      ElasticAPM.stop
      ElasticAPM::Transport::Worker.adapter = nil
    end

    before :all do
      module RailsTestApp
        class Application < Rails::Application
          RailsTestHelpers.setup_rails_test_config(config)

          config.elastic_apm.ignore_url_patterns = '/ping'
          config.elastic_apm.api_request_time = '200ms'
          config.elastic_apm.disable_start_message = true
          config.elastic_apm.metrics_interval = '2s'
          config.elastic_apm.capture_body = 'all'
          config.elastic_apm.pool_size = Concurrent.processor_count
          config.elastic_apm.log_path = 'spec/elastic_apm.log'
        end
      end

      class ApplicationController < ActionController::Base
        class FancyError < ::StandardError; end

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

        def raise_error
          raise FancyError, "Help! I'm trapped in a specfile!"
        end

        def report_message
          ElasticAPM.report_message 'Very very message'
          render_ok
        end

        def send_notification
          NotificationsMailer.ping('someone@example.com', 'Hello').deliver_now
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

      class NotificationsMailer < ActionMailer::Base
        def ping(recipient, subject)
          mail to: [recipient], subject: subject do |format|
            format.text { 'Hello you!' }
          end
        end
      end

      ElasticAPM::Transport::Worker.adapter = EventCollector::TestAdapter

      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        root to: 'application#index'
        get '/tags_and_context', to: 'application#context'
        post '/', to: 'application#create'
        get '/error', to: 'application#raise_error'
        get '/report_message', to: 'application#report_message'
        get '/send_notification', to: 'application#send_notification'
        get '/ping', to: 'application#ping'
      end
    end

    context 'Service metadata' do
      it 'includes Rails info' do
        responses = Array.new(10).map { get '/' }

        EventCollector.wait_for transactions: 10, spans: 20, timeout: 10

        expect(responses.last.body).to eq 'Yes!'
        expect(EventCollector.metadatas.length >= 1).to be true
        expect(EventCollector.transactions.length).to be 10

        service = EventCollector.metadatas.fetch(0)['service']
        expect(service['name']).to eq 'RailsTestApp'
        expect(service['framework']['name']).to eq 'Ruby on Rails'
        expect(service['framework']['version'])
          .to match(/\d+\.\d+\.\d+(\.\d+)?/)
      end
    end

    context 'log path' do
      it 'prepends Rails.root to log_path' do
        final_log_path = ElasticAPM.agent.config.log_path.to_s
        expect(final_log_path).to eq "#{Rails.root}/spec/elastic_apm.log"
      end
    end

    describe 'transactions' do
      context 'when a simple request is made' do
        it 'spans action and posts it' do
          get '/'

          EventCollector.wait_for transactions: 1, spans: 2

          name = EventCollector.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#index'
        end
      end

      context 'when tags and context are set' do
        it 'sets the values' do
          get '/tags_and_context'

          EventCollector.wait_for transactions: 1, spans: 2

          context = EventCollector.transactions.fetch(0)['context']
          expect(context['tags']).to eq('things' => 1)
          expect(context['custom']).to eq(
            'nested' => { 'banana' => 'explosion' }
          )
        end
      end

      context 'when there is user information' do
        it 'includes the info in transactions' do
          get '/'

          EventCollector.wait_for transactions: 1, spans: 2

          context = EventCollector.transactions.fetch(0)['context']
          user = context['user']
          expect(user['id']).to eq '1'
          expect(user['email']).to eq 'person@example.com'
        end
      end

      context 'when there are ignored url patterns defined' do
        it 'does not create events for the patterns' do
          get '/ping'
          get '/'

          EventCollector.wait_for transactions: 1, spans: 2

          name = EventCollector.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#index'
        end
      end

      context 'when there is sensitive data' do
        it 'filters the data and does not alter the original' do
          resp = post '/', access_token: 'abc123'

          EventCollector.wait_for transactions: 1, spans: 1

          expect(resp.body).to eq("HTTP Basic: Access denied.\n")
          expect(resp.original_headers['WWW-Authenticate']).to_not be nil
          expect(resp.original_headers['WWW-Authenticate'])
            .to_not eq '[FILTERED]'

          transaction, = EventCollector.transactions

          body = transaction.dig('context', 'request', 'body')
          expect(body['access_token']).to eq '[FILTERED]'

          response_headers = transaction.dig('context', 'response', 'headers')
          expect(response_headers['WWW-Authenticate']).to eq '[FILTERED]'
        end
      end

      context 'when json' do
        it 'validates the schema', type: :json_schema do
          get '/'

          EventCollector.wait_for transactions: 1

          metadata = EventCollector.metadatas.fetch(0)
          expect(metadata).to match_json_schema(:metadatas),
            metadata.inspect

          transaction = EventCollector.transactions.fetch(0)
          expect(transaction).to match_json_schema(:transactions),
            transaction.inspect

          span = EventCollector.spans.fetch(0)
          expect(span).to match_json_schema(:spans),
            span.inspect
        end
      end
    end

    describe 'errors' do
      context 'when there is an exception' do
        it 'creates an error and transaction event' do
          response = get '/error'

          EventCollector.wait_for transactions: 1, errors: 1, spans: 1

          expect(response.status).to be 500

          error = EventCollector.errors.fetch(0)
          expect(error['transaction_id']).to_not be_nil
          expect(error['transaction']['sampled']).to be true
          expect(error['context']).to_not be nil

          exception = error['exception']
          expect(exception['type']).to eq 'ApplicationController::FancyError'
          expect(exception['handled']).to eq false
        end
      end

      context 'when json' do
        it 'validates the schema' do
          get '/error'

          EventCollector.wait_for transactions: 1, errors: 1

          payload = EventCollector.errors.fetch(0)
          expect(payload).to match_json_schema(:errors),
            payload.inspect
        end
      end

      context 'when a message is reported' do
        it 'sends the message' do
          get '/report_message'

          EventCollector.wait_for transactions: 1, errors: 1, spans: 2

          error, = EventCollector.errors
          expect(error['log']).to be_a Hash
        end
      end

      describe 'mailers' do
        context 'when a mail is sent' do
          it 'spans the mail' do
            get '/send_notification'

            EventCollector.wait_for transactions: 1, spans: 3

            transaction, = EventCollector.transactions
            expect(transaction['name'])
              .to eq 'ApplicationController#send_notification'
            span = EventCollector.spans.find do |payload|
              payload['name'] == 'NotificationsMailer#ping'
            end
            expect(span).to_not be_nil
          end
        end
      end
    end

    describe 'metrics' do
      context 'when metrics are collected' do
        it 'sends them' do
          get '/'

          EventCollector.wait_for(
            transactions: 1,
            spans: 2,
            metricsets: 5,
            timeout: 10
          )
          EventCollector.wait_for do |parser|
            parser.transaction_metrics.count >= 2
          end
          EventCollector.wait_for do |parser|
            parser.span_metrics.count >= 3
          end

          transaction_metrics = EventCollector.transaction_metrics
          transaction_keys_counts =
            transaction_metrics.each_with_object(Hash.new { 0 }) do |set, keys|
              keys[set['samples'].keys] += 1
            end

          expect(transaction_keys_counts[
                   %w[transaction.duration.sum.us transaction.duration.count]
                 ]).to be >= 1
          expect(transaction_keys_counts[
                  %w[transaction.breakdown.count]
                 ]).to be >= 1

          span_metrics = EventCollector.span_metrics
          span_keys_counts =
            span_metrics.each_with_object(Hash.new { 0 }) do |set, keys|
              keys[set['samples'].keys] += 1
            end

          expect(span_keys_counts[
                     %w[span.self_time.sum.us span.self_time.count]
                 ]).to be >= 1
        end
      end
    end
  end
end
