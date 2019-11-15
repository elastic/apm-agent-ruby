# frozen_string_literal: true

module ElasticAPM
  # @api private
  module ChildDurations
    # @api private
    module Methods
      def child_durations
        @child_durations ||= Durations.new
      end

      def child_started
        child_durations.start
      end

      def child_stopped
        child_durations.stop
      end
    end

    # @api private
    class Durations
      def initialize
        @nesting_level = 0
        @start = nil
        @duration = 0
      end

      attr_reader :duration

      def start
        @nesting_level += 1
        @start = Util.micros if @nesting_level == 1
      end

      def stop
        @nesting_level -= 1
        @duration = (Util.micros - @start) if @nesting_level == 0
      end
    end
  end
end
