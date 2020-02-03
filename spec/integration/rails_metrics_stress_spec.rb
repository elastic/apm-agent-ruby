# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  enabled = true
else
  puts '[INFO] Skipping Rails spec'
end

if enabled
  require 'action_controller/railtie'

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

          config.elastic_apm.api_request_time = '200ms'
          config.elastic_apm.disable_start_message = true
          config.elastic_apm.metrics_interval = '1s'
          config.elastic_apm.pool_size = Concurrent.processor_count
          config.elastic_apm.log_path = 'spec/elastic_apm.log'
        end
      end

      class ApplicationController < ActionController::Base
        def index
          render_ok
        end

        def other
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
      end

      ElasticAPM::Transport::Worker.adapter = EventCollector::TestAdapter

      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        get '/other', to: 'application#other'
        root to: 'application#index'
      end
    end

    it 'handles multiple threads' do
      request_count = 20

      paths = ['/', '/other']

      count = Concurrent::AtomicFixnum.new

      Array.new(request_count).map do
        Thread.new do
          env = Rack::MockRequest.env_for(paths.sample)
          status, = Rails.application.call(env)
          expect(status).to be 200
          expect(env)
          count.increment
        end
      end.each(&:join)

      sleep 2 # wait for metrics to collect
      expect(EventCollector.metricsets_summary.values).to eq(
        Array.new(5).map { request_count }
      )
    end
  end
end
