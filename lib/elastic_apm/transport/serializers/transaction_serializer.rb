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
            context: transaction.context.to_h
          }

          if transaction.dropped_spans > 0
            base[:span_count] = {
              dropped: { total: transaction.dropped_spans }
            }
          end

          { transaction: base }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      end
    end
  end
end
