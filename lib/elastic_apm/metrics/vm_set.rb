# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class VMSet < Set
      include Logging

      def collect
        read!
        super
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def read!
        return if disabled?

        stat = GC.stat

        gauge(:'ruby.gc.count').value = stat[:count]
        gauge(:'ruby.threads').value = Thread.list.count
        gauge(:'ruby.heap.slots.live').value = stat[:heap_live_slots]

        gauge(:'ruby.heap.slots.free').value = stat[:heap_free_slots]
        gauge(:'ruby.heap.allocations.total').value =
          stat[:total_allocated_objects]

        return unless GC::Profiler.enabled?

        @total_time ||= 0
        @total_time += GC::Profiler.total_time
        GC::Profiler.clear
        gauge(:'ruby.gc.time').value = @total_time
      rescue TypeError => e
        error 'VM metrics encountered error: %s', e
        debug('Backtrace:') { e.backtrace.join("\n") }

        disable!
      end

      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end
  end
end
