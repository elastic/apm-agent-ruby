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
        thread_count = Thread.list.count

        sample = {
          'ruby.gc.count': stat[:count],
          'ruby.heap.slots.live': stat[:heap_live_slots],
          'ruby.heap.slots.free': stat[:heap_free_slots],
          'ruby.heap.allocations.total': stat[:total_allocated_objects],
          'ruby.threads': thread_count
        }

        return sample unless GC::Profiler.enabled?

        @total_time += GC::Profiler.total_time
        GC::Profiler.clear
        sample[:'ruby.gc.time'] = @total_time

        sample
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
