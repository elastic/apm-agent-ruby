# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class MetricsetSerializer < Serializer
        def build(metricset)
          {
            metricset: {
              timestamp: metricset.timestamp.to_i,
              tags: nil,
              samples: build_samples(metricset.samples)
            }
          }
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
