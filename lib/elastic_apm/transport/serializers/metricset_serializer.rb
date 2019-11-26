# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class MetricsetSerializer < Serializer
        def build(metricset)
          payload = {
            timestamp: metricset.timestamp.to_i,
            samples: build_samples(metricset.samples)
          }

          if metricset.tags?
            payload[:tags] = mixed_object(metricset.tags)
          end

          if metricset.transaction
            payload[:transaction] = metricset.transaction
          end

          if metricset.span
            payload[:span] = metricset.span
          end

          { metricset: payload }
        end

        private

        def build_samples(samples)
          samples.each_with_object({}) do |(key, value), hsh|
            hsh[key] = { value: value }
          end
        end
      end
    end
  end
end
