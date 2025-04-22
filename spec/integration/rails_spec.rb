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
  module MetricsHelpers
    def transaction_metrics
      @mock_intake.metricsets.select do |set|
        set && set['transaction'] && !set['span']
      end
    end

    def span_metrics
      @mock_intake.metricsets.select do |set|
        set && set['transaction'] && set['span']
      end
    end
  end

  require 'action_controller/railtie'
  require 'action_mailer/railtie'

  RSpec.describe 'Rails integration',
    :allow_running_agent,
    :spec_logger,
    :mock_intake do
    include Rack::Test::Methods
    include MetricsHelpers

    let(:app) do
      Rails.application
    end

    # Add some padding to make sure requests have settled down between examples
    before { sleep 0.25 }
    after { sleep 0.25 }

    after :all do
      ElasticAPM.stop
      ElasticAPM::Transport::Worker.adapter = nil
    end

    before :all do
      module RailsTestApp
        class Application < Rails::Application
          RailsTestHelpers.setup_rails_test_config(config)
          config.log_level = :debug

          config.elastic_apm.api_request_time = '200ms'
          config.elastic_apm.capture_body = 'all'
          config.elastic_apm.disable_start_message = true
          config.elastic_apm.log_path = 'spec/elastic_apm.log'
          config.elastic_apm.metrics_interval = '2s'
          config.elastic_apm.cloud_provider = 'none'
          config.elastic_apm.pool_size = Concurrent.processor_count
          config.elastic_apm.transaction_ignore_urls = '/ping'
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

        def test_body
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

      MockIntake.stub!

      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        root to: 'application#index'
        get '/tags_and_context', to: 'application#context'
        post '/', to: 'application#create'
        post '/test_body', to: 'application#test_body'
        get '/error', to: 'application#raise_error'
        get '/report_message', to: 'application#report_message'
        get '/send_notification', to: 'application#send_notification'
        get '/ping', to: 'application#ping'
      end
    end

    context 'Service metadata' do
      it 'includes Rails info' do
        responses = Array.new(10).map { get '/' }

        wait_for transactions: 10

        expect(responses.last.body).to eq 'Yes!'
        expect(@mock_intake.metadatas.length >= 1).to be true
        expect(@mock_intake.transactions.length).to be 10

        service = @mock_intake.metadatas[0]['service']
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

    context 'log level' do
      it 'uses the default log level' do
        log_level = ElasticAPM.agent.config.logger.level
        expect(log_level).to eq Logger::INFO
      end

      context 'when the log level is updated via central config' do
        before do
          ElasticAPM.agent.config.replace_options('log_level' => 'off')
        end

        it 'does not change the Rails log level' do
          log_level = Rails.logger.level
          expect(log_level).to eq Logger::DEBUG
        end

        it 'changes the ElasticAPM config log level' do
          log_level = ElasticAPM.agent.config.log_level
          expect(log_level).to eq Logger::FATAL
        end
      end
    end

    describe 'transactions' do
      context 'when a simple get request is made' do
        it 'spans action and posts it' do
          get '/'

          wait_for transactions: 1, spans: 2

          name = @mock_intake.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#index'
        end
      end

      context 'when a simple post request is made with a body' do
        it 'spans action and posts it' do
          post '/test_body', '{"data":{"a":"1","b":"five"}}',
               'CONTENT_TYPE' => 'application/json'

          wait_for transactions: 1, spans: 2

          name = @mock_intake.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#test_body'
          body = @mock_intake.transactions.fetch(0).dig('context', 'request', 'body')
          expect(body).to eq '{"data":{"a":"1","b":"five"}}'
        end
      end

      context 'when tags and context are set' do
        it 'sets the values' do
          get '/tags_and_context'

          wait_for transactions: 1, spans: 2

          context = @mock_intake.transactions.fetch(0)['context']
          expect(context['tags']).to eq('things' => 1)
          expect(context['custom']).to eq(
            'nested' => { 'banana' => 'explosion' }
          )
        end
      end

      context 'when there is user information' do
        it 'includes the info in transactions' do
          get '/'

          wait_for transactions: 1, spans: 2

          context = @mock_intake.transactions.fetch(0)['context']
          user = context['user']
          expect(user['id']).to eq '1'
          expect(user['email']).to eq 'person@example.com'
        end
      end

      context 'when there are ignored url patterns defined' do
        it 'does not create events for the patterns' do
          get '/ping'
          get '/'

          wait_for transactions: 1, spans: 2

          name = @mock_intake.transactions.fetch(0)['name']
          expect(name).to eq 'ApplicationController#index'
        end
      end

      context 'when there is sensitive data' do
        it 'filters the data and does not alter the original' do
          resp = post '/', access_token: 'abc123'

          wait_for transactions: 1, spans: 1

          expect(resp.body).to eq("HTTP Basic: Access denied.\n")

          transaction, = @mock_intake.transactions

          body = transaction.dig('context', 'request', 'body')
          expect(body['access_token']).to eq '[FILTERED]'
        end
      end

      context 'when json' do
        it 'validates the schema', type: :json_schema do
          get '/'

          wait_for transactions: 1

          metadata = @mock_intake.metadatas.fetch(0)
          expect(metadata).to match_json_schema(:metadatas),
            metadata.inspect

          transaction = @mock_intake.transactions.fetch(0)
          expect(transaction).to match_json_schema(:transactions),
            transaction.inspect

          span = @mock_intake.spans.fetch(0)
          expect(span).to match_json_schema(:spans),
            span.inspect
        end
      end
    end

    describe 'errors' do
      context 'when there is an exception' do
        it 'creates an error and transaction event' do
          response = get '/error'

          wait_for transactions: 1, errors: 1, spans: 1

          expect(response.status).to be 500

          error = @mock_intake.errors.fetch(0)
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

          wait_for transactions: 1, errors: 1

          payload = @mock_intake.errors.fetch(0)
          expect(payload).to match_json_schema(:errors),
            payload.inspect
        end
      end

      context 'when a message is reported' do
        it 'sends the message' do
          get '/report_message'

          wait_for transactions: 1, errors: 1, spans: 2

          error, = @mock_intake.errors
          expect(error['log']).to be_a Hash
        end
      end

      describe 'mailers' do
        context 'when a mail is sent' do
          it 'spans the mail' do
            get '/send_notification'

            wait_for transactions: 1, spans: 3

            transaction, = @mock_intake.transactions
            expect(transaction['name'])
              .to eq 'ApplicationController#send_notification'
            span = @mock_intake.spans.find do |payload|
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

          wait_for(
            transactions: 1,
            spans: 2,
            timeout: 10
          )
          wait_for { span_metrics.count >= 3 }

          span_keys_counts =
            span_metrics.each_with_object(Hash.new { 0 }) do |set, keys|
              keys[set['samples'].keys] += 1
            end

          expect(
            span_keys_counts[
              %w[span.self_time.sum.us span.self_time.count]
            ]
          ).to be >= 1
        end
      end
    end
  end
end
