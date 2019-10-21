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

      attr_reader :key, :initial_value, :tags

      def value=(value)
        @mutex.synchronize { @value = value }
      end

      def value
        @mutex.synchronize { @value }
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
