# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Metrics
    # @api private
    class Set
      def initialize(config)
        @config = config
        @metrics = {}
        @disabled = false
      end

      attr_reader :metrics

      def disable!
        @disabled = true
      end

      def disabled?
        @disabled
      end

      def counter(key, labels: nil)
        @metrics[key_with_labels(key, labels)] ||= Counter.new(key)
      end

      def gauge(key, labels: nil)
        @metrics[key_with_labels(key, labels)] ||= Gauge.new(key)
      end

      def timer(key, labels: nil)
        @metrics[key_with_labels(key, labels)] ||= Timer.new(key)
      end

      def collect(data = {})
        return data if disabled?

        @metrics.each_with_object(data) do |(key, metric), data|
          data[metric.key] = metric.value
        end
      end

      private

      def key_with_labels(key, labels)
        return [key] unless labels

        tuple = labels.keys.zip(labels.values)
        tuple.flatten!

        [key, *tuple]
      end
    end
  end
end
