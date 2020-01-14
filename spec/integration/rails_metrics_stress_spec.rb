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
          config.elastic_apm.metrics_interval = '200ms'
          config.elastic_apm.pool_size = Concurrent.processor_count
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
      request_count = 1000

      paths = ['/', '/other']

      pool = Concurrent::FixedThreadPool.new(Concurrent.processor_count)

      request_count.times do
        pool.post do
          print '.'
          get(paths.sample)
          # sleep rand(0.0..0.3)
        end
      end

      pool.shutdown
      pool.wait_for_termination
      puts ''

      sleep 0.3 # wait for metrics to collect

      summary =
        EventCollector.metricsets.each_with_object(
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
            next totals[key] += count['value']
          when 'template'
            totals[:template_span_self_times] += count['value']
            next
          else
            pp set
            raise 'Unmatched metric type'
          end

          # nothing
        end

      pp summary

      expect(summary.values.uniq).to eq([request_count])
    end
  end
end
