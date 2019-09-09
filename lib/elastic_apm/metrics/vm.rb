# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class VM
      include Logging

      def initialize(config)
        @config = config
        @total_time = 0
        @disabled = false
      end

      attr_reader :config
      attr_writer :disabled

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      def collect
        return if disabled?

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
      rescue TypeError => e
        error 'VM metrics encountered error: %s', e
        debug('Backtrace:') { e.backtrace.join("\n") }

        @disabled = true
        nil
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def disabled?
        @disabled
      end
    end
  end
end
