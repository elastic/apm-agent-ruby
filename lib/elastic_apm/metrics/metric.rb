# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class Metric
      def initialize(key, initial_value: nil)
        @key = key
        @initial_value = initial_value
        @value = initial_value
      end

      attr_reader :key, :initial_value
      attr_accessor :value

      def reset!
        self.value = initial_value
      end
    end

    class Counter < Metric
      def inc!
        @value += 1
      end

      def dec!
        @value -= 1
      end
    end

    class Gauge < Metric
      def initialize(key)
        super(key, initial_value: 0)
      end
    end

    class Timer < Metric
      def initialize(key)
        super(key, initial_value: 0)
        @count = 0
      end

      attr_accessor :count

      def update(duration, count: 0)
        self.value += duration
        self.count += count
      end

      def reset!
        super
        self.count = 0
      end
    end
  end
end
