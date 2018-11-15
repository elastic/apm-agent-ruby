# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class SpanSerializer < Serializer
        # rubocop:disable Metrics/MethodLength
        def build(span)
          {
            span: {
              id: span.id,
              transaction_id: span.transaction_id,
              parent_id: span.parent_id,
              name: span.name,
              type: span.type,
              duration: ms(span.duration),
              context: span.context&.to_h,
              stacktrace: span.stacktrace.to_a,
              timestamp: span.timestamp,
              trace_id: span.trace_id
            }
          }
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
