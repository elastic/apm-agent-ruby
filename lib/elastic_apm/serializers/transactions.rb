# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Transactions < Serializer
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build(transactions)
        {
          transactions: transactions.map do |transaction|
            base = {
              id: SecureRandom.uuid,
              name: transaction.name,
              type: transaction.type,
              result: transaction.result.to_s,
              duration: ms(transaction.duration),
              timestamp: micros_to_time(transaction.timestamp).utc.iso8601
            }

            if transaction.spans.any?
              base[:spans] = transaction.spans.map do |span|
                {
                  id: span.id,
                  parent: span.parent&.id,
                  name: span.name,
                  type: span.type,
                  start: ms(span.relative_start),
                  duration: ms(span.duration)
                }
              end
            end

            base
          end
        }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
