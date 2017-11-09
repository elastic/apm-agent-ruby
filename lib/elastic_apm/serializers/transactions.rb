# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Transactions
      def initialize(config)
        @config = config
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build(transactions)
        {
          transactions: transactions.map do |transaction|
            base = {
              id: SecureRandom.uuid,
              name: transaction.name,
              type: transaction.type,
              result: transaction.result,
              duration: ms(transaction.duration),
              timestamp: micros_to_time(transaction.timestamp)
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

      private

      def micros_to_time(micros)
        Time.at(ms(micros) / 1_000) # rubocop:disable Rails/TimeZone
      end

      def ms(micros)
        micros.to_f / 1_000
      end
    end
  end
end
