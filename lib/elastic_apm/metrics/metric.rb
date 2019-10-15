# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class Metric
      def initialize(key, initial_value: nil, tags: nil)
        @key = key
        @initial_value = initial_value
        @value = initial_value
        @tags = tags
      end

      attr_reader :key, :initial_value, :tags
      attr_accessor :value

      def reset!
        self.value = initial_value
      end

      def tags?
        tags&.any?
      end
    end

    class Counter < Metric
      def initialize(key, initial_value: 0, tags: nil)
        super(key, initial_value: initial_value, tags: tags)
      end

      def inc!
        @value += 1
      end

      def dec!
        @value -= 1
      end
    end

    class Gauge < Metric
      def initialize(key, tags: nil)
        super(key, initial_value: 0, tags: tags)
      end
    end

    class Timer < Metric
      def initialize(key, tags: nil)
        super(key, initial_value: 0, tags: tags)
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
