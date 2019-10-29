# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  require 'action_controller/railtie'

  RSpec.describe 'Rails logger', :allow_running_agent do
    before :all do
      module RailsTestApp
        class Application < Rails::Application
          configure_rails_for_test

          config.disable_send = true

          config.elastic_apm.logger = Logger.new(nil)
          config.logger = Logger.new(nil)
        end
      end

      class ApplicationController < ActionController::Base
      end

      RailsTestApp::Application.initialize!
    end

    after :all do
      ElasticAPM.stop
    end

    it 'sets the custom logger' do
      expect(Rails.logger).not_to be(ElasticAPM.agent.config.logger)
    end
  end
end
