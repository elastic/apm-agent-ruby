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

            if transaction.traces.any?
              base[:traces] = transaction.traces.map do |trace|
                {
                  id: trace.id,
                  parent: trace.parent&.id,
                  name: trace.name,
                  type: trace.type,
                  start: ms(trace.relative_start),
                  duration: ms(trace.duration)
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
