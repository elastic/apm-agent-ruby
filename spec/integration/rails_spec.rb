# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  require 'action_controller/railtie'
  require 'action_mailer/railtie'
  require 'elastic_apm/railtie'

  RSpec.describe 'Rails integration',
    :allow_leaking_subscriptions, :mock_intake do

    include Rack::Test::Methods

    def app
      @app ||= Rails.application
    end

    before :all do
      class RailsTestApp < Rails::Application
        config.secret_key_base = '__secret_key_base'
        config.consider_all_requests_local = false

        config.logger = Logger.new(nil)
        # config.logger = Logger.new(STDOUT)
        config.logger.level = Logger::DEBUG

        config.eager_load = false

        config.action_mailer.perform_deliveries = false

        config.elastic_apm.api_request_time = '100ms'
        config.elastic_apm.pool_size = Concurrent.processor_count
        config.elastic_apm.enabled_environments += %w[test]
        config.elastic_apm.service_name = 'RailsTestApp'
        config.elastic_apm.log_path = 'spec/elastic_apm.log'
        config.elastic_apm.log_level = Logger::DEBUG
        config.elastic_apm.ignore_url_patterns = '/ping'
      end

      class ApplicationController < ActionController::Base
        class FancyError < ::StandardError; end

        before_action do
          ElasticAPM.set_user(current_user)
        end

        def index
          render_ok
        end

        def context
          ElasticAPM.set_tag :things, 1
          ElasticAPM.set_custom_context nested: { banana: 'explosion' }
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
            format.text { 'Hello you!' }
          end
        end
      end

      RailsTestApp.initialize!
      RailsTestApp.routes.draw do
        get '/error', to: 'application#raise_error'
        get '/report_message', to: 'application#report_message'
        get '/tags_and_context', to: 'application#context'
        get '/send_notification', to: 'application#send_notification'
        get '/ping', to: 'application#ping'
        root to: 'application#index'
      end
    end

    after :all do
      %i[RailsTestApp ApplicationController].each do |const|
        Object.send(:remove_const, const)
      end

      Rails.application = nil
    end

    it 'knows Rails' do
      responses = Array.new(10).map { get '/' }

      wait_for transactions: 10

      expect(responses.last.body).to eq 'Yes!'
      expect(@mock_intake.metadatas.length >= 1).to be true
      expect(@mock_intake.transactions.length).to be 10

      service = @mock_intake.metadatas.first['service']
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

        wait_for transactions: 1

        name = @mock_intake.transactions.first['name']
        expect(name).to eq 'ApplicationController#index'
      end

      it 'can set tags and custom context' do
        get '/tags_and_context'

        wait_for transactions: 1

        context = @mock_intake.transactions.first['context']
        expect(context['tags']).to eq('things' => '1')
        expect(context['custom']).to eq('nested' => { 'banana' => 'explosion' })
      end

      it 'includes user information' do
        get '/'

        wait_for transactions: 1

        context = @mock_intake.transactions.first['context']
        user = context['user']
        expect(user['id']).to eq 1
        expect(user['email']).to eq 'person@example.com'
      end

      it 'ignores url patterns' do
        get '/ping'
        get '/'

        wait_for transactions: 1

        name = @mock_intake.transactions.first['name']
        expect(name).to eq 'ApplicationController#index'
      end

      it 'validates json schema', type: :json_schema do
        get '/'

        wait_for transactions: 1

        metadata = @mock_intake.metadatas.first
        expect(metadata).to match_json_schema(:metadatas)

        transaction = @mock_intake.transactions.first
        expect(transaction).to match_json_schema(:transactions)

        span = @mock_intake.spans.first
        expect(span).to match_json_schema(:spans)
      end
    end

    describe 'errors' do
      it 'handles exceptions and posts transaction' do
        response = get '/error'

        wait_for transactions: 1, errors: 1

        expect(response.status).to be 500

        error = @mock_intake.errors.first
        expect(error['transaction_id']).to_not be_nil

        exception = error['exception']
        expect(exception['type']).to eq 'ApplicationController::FancyError'
        expect(exception['handled']).to eq true
      end

      it 'validates json schema', type: :json_schema do
        get '/error'

        wait_for transactions: 1, errors: 1

        payload = @mock_intake.errors.first
        expect(payload).to match_json_schema(:errors)
      end

      it 'sends messages that validate' do
        get '/report_message'

        wait_for transactions: 1, errors: 1

        error, = @mock_intake.errors
        expect(error['log']).to be_a Hash
      end
    end

    describe 'mailers' do
      it 'spans mails' do
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

    after :all do
      ElasticAPM.stop
    end
  end
else
  puts '[INFO] Skipping Rails spec'
end
