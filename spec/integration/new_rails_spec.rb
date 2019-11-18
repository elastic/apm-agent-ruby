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

    after :all do
      ElasticAPM.stop
    end

    module RailsTestApp
      class Application < Rails::Application
        configure_rails_for_test

        config.action_mailer.perform_deliveries = false

        config.logger = Logger.new(SpecLogger)
        config.logger.level = Logger::DEBUG

        config.elastic_apm = config.elastic_apm.merge(DEFAULT_AGENT_OPTIONS)
        config.elastic_apm.capture_body = 'all'
        config.elastic_apm.ignore_url_patterns = '/ping'
        config.elastic_apm.log_path = 'spec/elastic_apm.log'
        config.elastic_apm.log_level = 0
        config.elastic_apm.pool_size = 1 #Concurrent.processor_count
        config.elastic_apm.api_request_time = '100ms'
        config.elastic_apm.metrics_interval = '2s'
      end
    end

    class ApplicationController < ActionController::Base
      class FancyError < ::StandardError;
      end

      before_action do
        ElasticAPM.set_user(current_user)
      end

      def index
        render_ok
      end

      http_basic_authenticate_with(
          name: 'dhh', password: 'secret123', only: [:create]
      )

      def create
        render_ok
      end

      def context
        ElasticAPM.set_label :things, 1
        ElasticAPM.set_custom_context nested: {banana: 'explosion'}
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

      def ping
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
          format.text {'Hello you!'}
        end
      end
    end

    before(:all) do
      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        get '/error', to: 'application#raise_error'
        get '/report_message', to: 'application#report_message'
        get '/tags_and_context', to: 'application#context'
        get '/send_notification', to: 'application#send_notification'
        get '/ping', to: 'application#ping'
        post '/', to: 'application#create'
        root to: 'application#index'
      end
    end

    before do
      allow_any_instance_of(ElasticAPM::Transport::Connection::Http).to receive(:write) do |http, str|
        parser.parse(str)
      end
    end

    let(:app) do
      Rails.application
    end

    let(:parser) do
      RequestParser.new
    end

    it 'knows Rails' do
      responses = Array.new(10).map { get '/' }

      parser.wait_for transactions: 10, spans: 20

      expect(responses.last.body).to eq 'Yes!'
      expect(responses.last.body).to eq 'Yes!'
      expect(parser.metadatas.length >= 1).to be true
      expect(parser.transactions.length).to be 10

      service = parser.metadatas.fetch(0)['service']
      expect(service['name']).to eq 'RailsTestApp'
      expect(service['framework']['name']).to eq 'Ruby on Rails'
      expect(service['framework']['version'])
        .to match(/\d+\.\d+\.\d+(\.\d+)?/)
    end

    it 'prepends Rails.root to log_path' do
      final_log_path = ElasticAPM.agent.config.log_path.to_s
      expect(final_log_path).to eq "#{Rails.root}/spec/elastic_apm.log"
    end

    describe 'transactions' do
      it 'spans action and posts it' do
        get '/'

        parser.wait_for transactions: 1, spans: 2

        name = parser.transactions.fetch(0)['name']
        expect(name).to eq 'ApplicationController#index'
      end

      it 'can set tags and custom context' do
        get '/tags_and_context'

        parser.wait_for transactions: 1, spans: 2

        context = parser.transactions.fetch(0)['context']
        expect(context['tags']).to eq('things' => 1)
        expect(context['custom']).to eq('nested' => { 'banana' => 'explosion' })
      end

      it 'includes user information' do
        get '/'

        parser.wait_for transactions: 1, spans: 2

        context = parser.transactions.fetch(0)['context']
        user = context['user']
        expect(user['id']).to eq '1'
        expect(user['email']).to eq 'person@example.com'
      end

      it 'ignores url patterns' do
        get '/ping'
        get '/'

        parser.wait_for transactions: 1, spans: 2

        name = parser.transactions.fetch(0)['name']
        expect(name).to eq 'ApplicationController#index'
      end

      it "filters sensitive looking data, but doesn't touch original" do
        resp = post '/', access_token: 'abc123'

        parser.wait_for transactions: 1, spans: 1

        expect(resp.body).to eq("HTTP Basic: Access denied.\n")
        expect(resp.original_headers['WWW-Authenticate']).to_not be nil
        expect(resp.original_headers['WWW-Authenticate']).to_not eq '[FILTERED]'

        transaction, = parser.transactions

        body = transaction.dig('context', 'request', 'body')
        expect(body['access_token']).to eq '[FILTERED]'

        response_headers = transaction.dig('context', 'response', 'headers')
        expect(response_headers['WWW-Authenticate']).to eq '[FILTERED]'
      end

      it 'validates json schema', type: :json_schema do
        get '/'

        parser.wait_for transactions: 1, spans: 1, metadatas: 1

        metadata = parser.metadatas.fetch(0)
        expect(metadata).to match_json_schema(:metadatas),
          metadata.inspect

        transaction = parser.transactions.fetch(0)
        expect(transaction).to match_json_schema(:transactions),
          transaction.inspect

        span = parser.spans.fetch(0)
        expect(span).to match_json_schema(:spans),
          span.inspect
      end
    end

    describe 'errors' do
      it 'handles exceptions and posts transaction' do
        response = get '/error'

        parser.wait_for transactions: 1, errors: 1, spans: 1

        expect(response.status).to be 500

        error = parser.errors.fetch(0)
        expect(error['transaction_id']).to_not be_nil
        expect(error['transaction']['sampled']).to be true
        expect(error['context']).to_not be nil

        exception = error['exception']
        expect(exception['type']).to eq 'ApplicationController::FancyError'
        expect(exception['handled']).to eq false
      end

      it 'validates json schema', type: :json_schema do
        get '/error'

        parser.wait_for transactions: 1, errors: 1

        payload = parser.errors.fetch(0)
        expect(payload).to match_json_schema(:errors),
                           payload.inspect
      end

      it 'sends messages that validate' do
        get '/report_message'

        parser.wait_for transactions: 1, errors: 1, spans: 2

        error, = parser.errors
        expect(error['log']).to be_a Hash
      end
    end

    describe 'mailers' do
      it 'spans mails' do
        get '/send_notification'

        parser.wait_for transactions: 1, spans: 3

        transaction, = parser.transactions
        expect(transaction['name'])
            .to eq 'ApplicationController#send_notification'
        span = parser.spans.find do |payload|
          payload['name'] == 'NotificationsMailer#ping'
        end
        expect(span).to_not be_nil
      end
    end

    describe 'metrics' do
      it 'gathers metrics' do
        get '/'

        parser.wait_for transactions: 1, spans: 2

        select_transaction_metrics = lambda do |intake|
          intake.metricsets.select { |set| set['transaction'] && !set['span'] }
        end

        parser.wait_for { |intake| select_transaction_metrics.call(intake).count >= 2 }
        transaction_metrics = select_transaction_metrics.call(parser)

        keys_counts =
          transaction_metrics.each_with_object(Hash.new { 0 }) do |set, keys|
            keys[set['samples'].keys] += 1
          end

        expect(keys_counts[
          %w[transaction.duration.sum.us transaction.duration.count]
        ]).to be >= 1
        expect(keys_counts[%w[transaction.breakdown.count]]) .to be >= 1

        select_span_metrics = lambda do |intake|
          intake.metricsets.select { |set| set['transaction'] && set['span'] }
        end

        parser.wait_for { |intake| select_span_metrics.call(intake).count >= 3 }
        span_metrics = select_span_metrics.call(parser)

        keys_counts =
          span_metrics.each_with_object(Hash.new { 0 }) do |set, keys|
            keys[set['samples'].keys] += 1
          end

        expect(keys_counts[
          %w[span.self_time.sum.us span.self_time.count]
        ]).to be >= 1
      end
    end
  end
end
