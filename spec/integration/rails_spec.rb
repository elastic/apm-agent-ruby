# frozen_string_literal: true

require 'spec_helper'

if defined? Rails
  require 'action_controller/railtie'
  require 'elastic_apm/railtie'

  RSpec.describe 'Rails integration' do
    include Rack::Test::Methods

    def boot
      RailsTestApp.initialize!
      RailsTestApp.routes.draw do
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
        # config.logger = Logger.new(STDOUT)
        config.logger.level = Logger::DEBUG

        config.eager_load = false

        config.elastic_apm.app_name = 'RailsTestApp'
        # post transactions right away
        config.elastic_apm.transaction_send_interval = nil
        # and debug them
        config.elastic_apm.debug_transactions = true
      end

      class PagesController < ActionController::Base
        def index
          if Rails.version.start_with?('4')
            render text: 'Yes!'
          else
            render plain: 'Yes!'
          end
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

    it 'traces action and posts it', :with_fake_server do
      # test config from Rails.app.config
      expect(ElasticAPM.agent.config.debug_transactions).to be true

      response = get '/'
      sleep 0.1

      expect(response.body).to eq 'Yes!'
      expect(FakeServer.requests.length).to be 1

      request = FakeServer.requests.last
      expect(request.dig('app', 'name')).to eq 'RailsTestApp'
      expect(request.dig('transactions', 0, 'name'))
        .to eq 'PagesController#index'
    end

    after do
      ElasticAPM.stop
    end
  end
end
