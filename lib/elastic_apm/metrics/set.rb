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

      def counter(key, tags: nil, **args)
        @metrics[key_with_tags(key, tags)] ||=
          Counter.new(key, tags: tags, **args)
      end

      def gauge(key, tags: nil, **args)
        @metrics[key_with_tags(key, tags)] ||=
          Gauge.new(key, tags: tags, **args)
      end

      def timer(key, tags: nil, **args)
        @metrics[key_with_tags(key, tags)] ||=
          Timer.new(key, tags: tags, **args)
      end

      def collect
        return if disabled?

        @metrics.each_with_object({}) do |(key, metric), sets|
          name, *tags = key
          sets[tags] ||= Metricset.new
          set = sets[tags]
          set.samples[name] = metric.collect
          set.merge_tags! metric.tags
        end.values
      end

      private

      def key_with_tags(key, tags)
        return key unless tags

        tuple = tags.keys.zip(tags.values)
        tuple.flatten!

        [key, *tuple]
      end
    end
  end
end
