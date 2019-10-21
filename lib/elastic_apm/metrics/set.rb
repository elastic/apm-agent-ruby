# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Metrics
    NOOP = NoopMetric.new

    # @api private
    class Set
      DISTINCT_LABEL_LIMIT = 1000

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
        metric(Counter, key, tags: tags, **args)
      end

      def gauge(key, tags: nil, **args)
        metric(Gauge, key, tags: tags, **args)
      end

      def timer(key, tags: nil, **args)
        metric(Timer, key, tags: tags, **args)
      end

      def metric(kls, key, tags: nil, **args)
        key = key_with_tags(key, tags)
        return metrics[key] if metrics[key]

        if metrics.length < DISTINCT_LABEL_LIMIT
          metrics[key] =
            kls.new(key, tags: tags, **args)
        else
          metrics[key] = NOOP
        end
      end

      def collect
        return if disabled?

        metrics.each_with_object({}) do |(key, metric), sets|
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
