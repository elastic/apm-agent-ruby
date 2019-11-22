# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class TransactionSerializer < Serializer
        def context_serializer
          @context_serializer ||= ContextSerializer.new(config)
        end

        def build(transaction)
          {
            transaction: {
              id: transaction.id,
              trace_id: transaction.trace_id,
              parent_id: transaction.parent_id,
              name: keyword_field(transaction.name),
              type: keyword_field(transaction.type),
              result: keyword_field(transaction.result.to_s),
              duration: ms(transaction.duration),
              timestamp: transaction.timestamp,
              sampled: transaction.sampled?,
              context: context_serializer.build(transaction.context),
              span_count: {
                started: transaction.started_spans,
                dropped: transaction.dropped_spans
              }
            }
          }
        end
      end
    end
  end
end
