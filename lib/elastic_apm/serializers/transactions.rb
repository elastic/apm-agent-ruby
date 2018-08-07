# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Transactions < Serializer
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build(transaction)
        base = {
          id: transaction.id,
          name: transaction.name,
          type: transaction.type,
          result: transaction.result.to_s,
          duration: ms(transaction.duration),
          timestamp: micros_to_time(transaction.timestamp).utc.iso8601(3),
          spans: transaction.spans.map { |s| build_span(s) },
          sampled: transaction.sampled,
          context: transaction.context.to_h
        }

        if transaction.dropped_spans > 0
          base[:span_count] = { dropped: { total: transaction.dropped_spans } }
        end

        base
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def build_all(transactions)
        { transactions: Array(transactions).map { |t| build(t) } }
      end

      private

      # rubocop:disable Metrics/AbcSize
      def build_span(span)
        {
          id: span.id,
          parent: span.parent && span.parent.id,
          name: span.name,
          type: span.type,
          start: ms(span.relative_start),
          duration: ms(span.duration),
          context: span.context && { db: span.context.to_h },
          stacktrace: span.stacktrace.to_a
        }
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
