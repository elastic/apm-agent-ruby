# frozen_string_literal: true

require 'elastic_apm/metricset'

module ElasticAPM
  # @api private
  module Metrics
    MUTEX = Mutex.new

    def self.new(config, &block)
      Collector.new(config, &block)
    end

    def self.platform
      @platform ||= Gem::Platform.local.os.to_sym
    end

    # @api private
    class Collector
      include Logging

      TIMEOUT_INTERVAL = 5 # seconds

      def initialize(config, tags: nil, &block)
        @config = config
        @tags = tags
        @samplers = [CpuMem, VM].map do |kls|
          debug "Adding metrics collector '#{kls}'"
          kls.new(config)
        end
        @callback = block
      end

      attr_reader :config, :samplers, :callback, :tags

      # rubocop:disable Metrics/MethodLength
      def start
        unless config.collect_metrics?
          debug 'Skipping metrics'
          return
        end

        debug 'Starting metrics'

        @timer_task = Concurrent::TimerTask.execute(
          run_now: true,
          execution_interval: config.metrics_interval,
          timeout_interval: TIMEOUT_INTERVAL
        ) do
          begin
            debug 'Collecting metrics'
            collect_and_send
            true
          rescue StandardError => e
            error 'Error while collecting metrics: %e', e.inspect
            debug { e.backtrace.join("\n") }
            false
          end
        end

        @running = true
      end
      # rubocop:enable Metrics/MethodLength

      def stop
        return unless running?

        debug 'Stopping metrics'

        @timer_task.shutdown
        @running = false
      end

      def running?
        !!@running
      end

      def collect_and_send
        metricset = Metricset.new(tags: tags, **collect)
        return if metricset.empty?

        callback.call(metricset)
      end

      def collect
        MUTEX.synchronize do
          samplers.each_with_object({}) do |sampler, samples|
            next unless (sample = sampler.collect)
            samples.merge!(sample)
          end
        end
      end
    end
  end
end

require 'elastic_apm/metrics/cpu_mem'
require 'elastic_apm/metrics/vm'
