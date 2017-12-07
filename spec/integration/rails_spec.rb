# frozen_string_literal: true

require 'spec_helper'

if defined? Rails
  require 'action_controller/railtie'
  require 'elastic_apm/railtie'

  RSpec.describe 'Rails integration',
                 :allow_leaking_subscriptions, :with_fake_server do
    include Rack::Test::Methods

    def boot
      RailsTestApp.initialize!
      RailsTestApp.routes.draw do
        get '/error', to: 'pages#raise_error'
        root to: 'pages#index'
      end
    end

    def app
      @app ||= Rails.application
    end

    before :all do
      class RailsTestApp < Rails::Application
        config.secret_key_base = '__secret_key_base'

        config.logger = Logger.new(nil)
        config.logger = Logger.new(STDOUT)
        config.logger.level = Logger::DEBUG

        config.eager_load = false

        config.elastic_apm.app_name = 'RailsTestApp'
        # post transactions right away
        config.elastic_apm.transaction_send_interval = nil
        # and debug them
        config.elastic_apm.debug_transactions = true
      end

      class PagesController < ActionController::Base
        class FancyError < ::StandardError; end

        def index
          if Rails.version.start_with?('4')
            render text: 'Yes!'
          else
            render plain: 'Yes!'
          end
        end

        def raise_error
          raise FancyError, "Help! I'm trapped in a specfile!"
        end
      end

      boot
    end

    after :all do
      %i[RailsTestApp PagesController].each do |const|
        Object.send(:remove_const, const)
      end

      Rails.application = nil
    end

    before { allow(SecureRandom).to receive(:uuid) { '_RANDOM' } }

    it 'spans action and posts it' do
      # test config from Rails.app.config
      expect(ElasticAPM.agent.config.debug_transactions).to be true

      response = get '/'
      wait_for_requests_to_finish 1

      expect(response.body).to eq 'Yes!'
      expect(FakeServer.requests.length).to be 1

      request = FakeServer.requests.last
      expect(request.dig('service', 'name')).to eq 'RailsTestApp'
      expect(request.dig('transactions', 0, 'name'))
        .to eq 'PagesController#index'
    end

    it 'adds an exception handler and handles exceptions '\
      'AND posts transaction' do
      response = get '/error'
      wait_for_requests_to_finish 2

      expect(response.status).to be 500

      expect(FakeServer.requests.length).to be 2

      request = FakeServer.requests.first
      expect(request.dig('errors', 0, 'exception', 'type'))
        .to eq 'PagesController::FancyError'
    end

    after :all do
      ElasticAPM.stop
    end
  end
end
