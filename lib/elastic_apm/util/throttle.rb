# frozen_string_literal: true

module ElasticAPM
  module Util
    # @api private

    # Usage example:
    #   Throttle.new(5) { thing to only do once per 5 secs }
    class Throttle
      def initialize(buffer_secs, &block)
        @buffer_secs = buffer_secs
        @block = block
      end

      def call
        if @last_call && seconds_since_last_call < @buffer_secs
          return @last_result
        end

        @last_call = now
        @last_result = @block.call
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def seconds_since_last_call
        now - @last_call
      end
    end
  end
end
