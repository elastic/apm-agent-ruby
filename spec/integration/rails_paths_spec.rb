# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  require 'action_controller/railtie'

  RSpec.describe 'Rails paths' do
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
    end

    before do
      allow(RailsTestApp::Application.config.paths['app/views'])
        .to receive(:existent).and_return(['test/path'])
      allow(Rails).to receive(:root).and_return(Pathname.new('rootz'))

      RailsTestApp::Application.initialize!
    end

    after do
      ElasticAPM.stop
    end

    it 'sets the paths' do
      expect(ElasticAPM.agent.config.__view_paths).to eq(['test/path'])
      expect(ElasticAPM.agent.config.__root_path).to eq('rootz')
    end
  end
end
