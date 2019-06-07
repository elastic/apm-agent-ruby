# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class VM
      def initialize(_config)
        @total_time = 0
      end

      # rubocop:disable Metrics/MethodLength
      def collect
        stat = GC.stat
        @total_time += GC::Profiler.total_time
        GC::Profiler.clear
        thread_count = Thread.list.count

        {
          'ruby.gc.count': stat[:count],
          'ruby.gc.time': @total_time,
          'ruby.heap.live': stat[:heap_live_slots],
          'ruby.heap.free': stat[:heap_free_slots],
          'ruby.allocations.total': stat[:total_allocated_objects],
          'ruby.threads': thread_count
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
