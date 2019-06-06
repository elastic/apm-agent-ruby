# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class VM
      include Logging

      SCOPE = 'runtime.ruby.'

      # @api private
      class Sampler
        def sample
          stat = GC.stat
          total_time = GC::Profiler.total_time
          thread_count = Thread.list.count

          stat.merge(
            gc_total_time: total_time,
            thread_count: thread_count
          )
        end
      end

      def initialize(config)
        @config = config
        @sampler = Sampler.new
      end

      attr_reader :config, :sampler

      def sample
        @sampler.sample
      end

      def collect
        return unless sampler

        sample.each_with_object({}) do |(key, value), snap|
          snap[:"#{SCOPE}#{key}"] = value
        end
      end
    end
  end
end
