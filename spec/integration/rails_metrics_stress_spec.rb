# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  enabled = true
else
  puts '[INFO] Skipping Rails spec'
end

if enabled
  require 'action_controller/railtie'

  RSpec.describe 'Rails integration',
    :mock_intake, :allow_running_agent, :spec_logger do
    include Rack::Test::Methods

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

      MockIntake.stub!

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
          # The request is occasionally unsuccessful so we want to only
          # compare the metricset counts to the number of successful
          # requests.
          count.increment if status == 200
        end
      end.each(&:join)

      sleep 2 # wait for metrics to settle

      metricsets_summary =
        MockIntake.metricsets.each_with_object(
          Hash.new { 0 }
        ) do |set, totals|
          next unless set['transaction']

          samples = set['samples']

          if (count = samples['transaction.duration.count'])
            next totals[:transaction_durations] += count['value']
          end

          if (count = samples['transaction.breakdown.count'])
            next totals[:transaction_breakdowns] += count['value']
          end

          count = set['samples']['span.self_time.count']

          case set.dig('span', 'type')
          when 'app'
            subtype = set.dig('span', 'subtype')
            key = :"app_span_self_times__#{subtype || 'nil'}"
            next totals && totals[key] += count['value']
          when 'template'
            totals && totals[:template_span_self_times] += count['value']
            next
          else
            pp set
            raise 'Unmatched metric type'
          end
        end

      expect(metricsets_summary.values).to eq(
        Array.new(5).map { count.value }
      )
    end
  end
end
