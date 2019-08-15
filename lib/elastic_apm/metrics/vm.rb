# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class VM
      def initialize(_config)
        @total_time = 0
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def collect
        stat = GC.stat
        thread_count = Thread.list.count

        sample = {
          'ruby.gc.count': stat[:count],
          'ruby.threads': thread_count
        }

        (live_slots = stat[:heap_live_slots]) &&
          sample[:'ruby.heap.slots.live'] = live_slots
        (heap_slots = stat[:heap_free_slots]) &&
          sample[:'ruby.heap.slots.free'] = heap_slots
        (allocated = stat[:total_allocated_objects]) &&
          sample[:'ruby.heap.allocations.total'] = allocated

        return sample unless GC::Profiler.enabled?

        @total_time += GC::Profiler.total_time
        GC::Profiler.clear
        sample[:'ruby.gc.time'] = @total_time

        sample
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end
  end
end
