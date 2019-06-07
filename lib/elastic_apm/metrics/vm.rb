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
        end
      end

      def initialize(config)
        @config = config
        @sampler = Sampler.new
      end

      def collect
        stat = GC.stat
        total_time = GC::Profiler.total_time
        thread_count = Thread.list.count

        {
          'ruby.gc.count': stat[:count],
          'ruby.gc.time': total_time,
          'ruby.heap.live': stat[:heap_live_slots],
          'ruby.heap.free': stat[:heap_free_slots],
          'ruby.threads': thread_count
        }
      end
    end
  end
end
