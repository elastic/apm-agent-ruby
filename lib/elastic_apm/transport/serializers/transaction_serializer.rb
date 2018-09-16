# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class TransactionSerializer < Serializer
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def build(transaction)
          base = {
            id: transaction.id,
            name: transaction.name,
            type: transaction.type,
            result: transaction.result.to_s,
            duration: ms(transaction.duration),
            timestamp: micros_to_time(transaction.timestamp).utc.iso8601(3),
            sampled: transaction.sampled,
            context: transaction.context.to_h,
            trace_id: transaction.trace_id
          }

          base[:span_count] = {
            started: transaction.started_spans,
            dropped: transaction.dropped_spans
          }

          { transaction: base }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      end
    end
  end
end
