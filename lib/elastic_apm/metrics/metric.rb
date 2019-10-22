# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class Metric
      def initialize(
        key,
        initial_value: nil,
        tags: nil,
        reset_on_collect: false
      )
        @key = key
        @initial_value = initial_value
        @value = initial_value
        @tags = tags
        @reset_on_collect = reset_on_collect
        @mutex = Mutex.new
      end

      attr_reader :key, :initial_value, :tags, :value

      def value=(value)
        @mutex.synchronize { @value = value }
      end

      def reset!
        self.value = initial_value
      end

      def tags?
        !!tags&.any?
      end

      def reset_on_collect?
        @reset_on_collect
      end

      def collect
        collected = value
        self.value = initial_value if reset_on_collect?

        return nil if reset_on_collect? && collected == 0

        collected
      end
    end

    # @api private
    class NoopMetric
      # rubocop:disable Style/MethodMissingSuper
      # TODO: Is this expensive
      # 1. Keep this (not expensive?)
      # 2. Override #send
      # 3. Explicitly define all existing methods
      # 4. Handle one level up
      def method_missing(*_); end
      # rubocop:enable Style/MethodMissingSuper
    end

    # @api private
    class Counter < Metric
      def initialize(key, initial_value: 0, **args)
        super(key, initial_value: initial_value, **args)
      end

      def inc!
        @value += 1
      end

      def dec!
        @value -= 1
      end
    end

    # @api private
    class Gauge < Metric
      def initialize(key, **args)
        super(key, initial_value: 0, **args)
      end
    end

    # @api private
    class Timer < Metric
      def initialize(key, **args)
        super(key, initial_value: 0, **args)
        @count = 0
      end

      attr_accessor :count

      def update(duration, delta: 0)
        @mutex.synchronize do
          @value += duration
          @count += delta
        end
      end

      def count=(value)
        @mutex.synchronize { @count = value }
      end

      def reset!
        super
        self.count = 0
      end
    end
  end
end
