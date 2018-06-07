# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  require 'action_controller/railtie'
  require 'action_mailer/railtie'
  require 'elastic_apm/railtie'

  RSpec.describe 'Rails integration',
    :allow_leaking_subscriptions, :with_fake_server do

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

        config.elastic_apm.enabled_environments += %w[test]
        config.elastic_apm.service_name = 'RailsTestApp'
        config.elastic_apm.flush_interval = nil
        config.elastic_apm.debug_transactions = true
        config.elastic_apm.http_compression = false
        config.elastic_apm.log_path = 'spec/elastic_apm.log'
      end

      class PagesController < ActionController::Base
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
        get '/error', to: 'pages#raise_error'
        get '/report_message', to: 'pages#report_message'
        get '/tags_and_context', to: 'pages#context'
        get '/send_notification', to: 'pages#send_notification'
        root to: 'pages#index'
      end
    end

    after :all do
      %i[RailsTestApp PagesController].each do |const|
        Object.send(:remove_const, const)
      end

      Rails.application = nil
    end

    it 'knows Rails' do
      # test config from Rails.app.config
      expect(ElasticAPM.agent.config.debug_transactions).to be true

      response = get '/'
      wait_for_requests_to_finish 1

      expect(response.body).to eq 'Yes!'

      service = FakeServer.requests.first['service']
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
        wait_for_requests_to_finish 1

        expect(FakeServer.requests.length).to be 1
        name = FakeServer.requests.first['transactions'][0]['name']
        expect(name).to eq 'PagesController#index'
      end

      it 'can set tags and custom context' do
        get '/tags_and_context'
        wait_for_requests_to_finish 1

        payload, = FakeServer.requests
        context = payload['transactions'][0]['context']
        expect(context['tags']).to eq('things' => '1')
        expect(context['custom']).to eq('nested' => { 'banana' => 'explosion' })
      end

      it 'includes user information' do
        get '/'
        wait_for_requests_to_finish 1

        context = FakeServer.requests.first['transactions'][0]['context']
        user = context['user']
        expect(user['id']).to eq 1
        expect(user['email']).to eq 'person@example.com'
      end

      it 'validates json schema', type: :json_schema do
        get '/'
        wait_for_requests_to_finish 1

        payload, = FakeServer.requests
        expect(payload).to match_json_schema(:transactions)
      end
    end

    describe 'errors' do
      it 'adds an exception handler and handles exceptions '\
        'AND posts transaction' do
        response = get '/error'
        wait_for_requests_to_finish 2

        expect(response.status).to be 500
        expect(FakeServer.requests.length).to be 2

        error_request =
          FakeServer.requests.find { |r| r.key?('errors') }
        error = error_request['errors'][0]

        expect(error['transaction']['id']).to_not be_nil

        exception = error['exception']
        expect(exception['type']).to eq 'PagesController::FancyError'
        expect(exception['handled']).to eq true
      end

      it 'validates json schema', type: :json_schema do
        get '/error'
        wait_for_requests_to_finish 2

        payload =
          FakeServer.requests.find { |r| r.key?('errors') }
        expect(payload).to match_json_schema(:errors)
      end

      it 'sends messages that validate', type: :json_schema do
        get '/report_message'
        wait_for_requests_to_finish 2
        sleep 1 if RSpec::Support::Ruby.jruby? # so sorry

        payload =
          FakeServer.requests.find { |r| r.key?('errors') }
        expect(payload.dig('errors', 0, 'log')).to_not be_nil
        expect(payload).to match_json_schema(:errors)
      end
    end

    describe 'mailers' do
      it 'spans mails' do
        get '/send_notification'
        wait_for_requests_to_finish 1

        payload, = FakeServer.requests
        name = payload.dig('transactions', 0, 'spans', 1, 'name')
        expect(name).to eq 'NotificationsMailer#ping'
      end
    end

    after :all do
      ElasticAPM.stop
    end
  end
else
  puts '[INFO] Skipping Rails spec'
end
