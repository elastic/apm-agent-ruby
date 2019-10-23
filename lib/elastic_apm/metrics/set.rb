# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Metrics
    NOOP = NoopMetric.new

    # @api private
    class Set
      include Logging

      DISTINCT_LABEL_LIMIT = 1000

      def initialize(config)
        @config = config
        @metrics = {}
        @disabled = false
        # TODO: Do we need a lock in Set?
        @lock = Mutex.new
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

      # rubocop:disable Metrics/MethodLength
      def metric(kls, key, tags: nil, **args)
        key = key_with_tags(key, tags)
        return metrics[key] if metrics[key]

        @lock.synchronize do
          return metrics[key] if metrics[key]

          metrics[key] =
            if metrics.length < DISTINCT_LABEL_LIMIT
              kls.new(key, tags: tags, **args)
            else
              if !@label_limit_logged
                warn(
                  "The limit of %d metricsets has been reached, no new " \
                   "metricsets will be created.",
                   DISTINCT_LABEL_LIMIT
                )
                @label_limit_logged = true
              end

              NOOP
            end
        end
      end
      # rubocop:enable Metrics/MethodLength

      def collect
        return if disabled?

        metrics.each_with_object({}) do |(key, metric), sets|
          next unless (value = metric.collect)

          name, *tags = key
          sets[tags] ||= Metricset.new
          set = sets[tags]
          set.samples[name] = value
          set.merge_tags! metric.tags
        end.values
      end

      private

      def key_with_tags(key, tags)
        return key unless tags

        tuple = tags.keys.zip(tags.values)
        tuple.flatten!
        tuple.unshift(key)
      end
    end
  end
end
