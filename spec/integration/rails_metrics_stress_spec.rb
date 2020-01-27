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

          config.logger = Logger.new(nil)
          config.elastic_apm.metrics_interval = '1s' # '200ms'
          puts "processor count: #{Concurrent.processor_count}"
          config.elastic_apm.pool_size = Concurrent.processor_count
          config.elastic_apm.logger = Logger.new($stdout)
          config.elastic_apm.log_level = 0
          config.disable_metrics = 'vm'
          #config.metrics_interval = 0
          #config.breakdown_metrics = false
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

      count = Concurrent::AtomicFixnum.new

      threads = []

      begin
        Array.new(request_count).map do
          threads << Thread.new do
            print '.'
            #get(paths.sample)
            env = Rack::MockRequest.env_for('/')
            status, = Rails.application.call(env)
            expect(status).to be 200
            expect(env)
            count.increment
          end
        end
        threads.each(&:join)
        puts ''
      rescue => e
        puts "got error: #{e}"
      end

      # pool = Concurrent::FixedThreadPool.new(Concurrent.processor_count)
      # count = Concurrent::AtomicFixnum.new

      # request_count.times do
      #   pool.post do
      #     print '.'
      #     get(paths.sample)
      #     count.increment
      #     # sleep rand(0.0..0.3)
      #   end
      # end

      # pool.shutdown
      # pool.wait_for_termination

      sleep 2 # wait for metrics to collect

      pp(
          atomic_count: count,
          metrics_count: ElasticAPM.agent.metrics.sets.count,
          transaction_count: EventCollector.transactions.count,
          span_count: EventCollector.spans.count,
          event_requests_count: EventCollector.requests.count
      )

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
              next totals && totals[key] += count['value']
            when 'template'
              totals && totals[:template_span_self_times] += count['value']
              next
            else
              pp set
              raise 'Unmatched metric type'
            end
          end

      pp summary

      # # =>
      # {:template_span_self_times=>1000,
      #  :app_span_self_times__controller=>1000,
      #  :transaction_breakdowns=>1000,
      #  :app_span_self_times__nil=>1000,
      #  :transaction_durations=>1000}

      expect(summary.values).to eq(Array.new(5).map { request_count })
    end
  end
end
