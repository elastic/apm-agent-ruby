# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class SpanSerializer < Serializer
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def build(span)
          {
            span: {
              id: span.id,
              transaction_id: span.transaction_id,
              parent_id: span.parent_id || span.transaction_id,
              name: span.name,
              type: span.type,
              start: ms(span.relative_start),
              duration: ms(span.duration),
              context: span.context && { db: span.context.to_h },
              stacktrace: span.stacktrace.to_a,
              timestamp: span.timestamp,
              trace_id: span.trace_id
            }
          }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      end
    end
  end
end
