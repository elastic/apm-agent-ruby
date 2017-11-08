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
        Time.at(micros / 1_000_000)
      end

      def ms(micros)
        micros / 1_000
      end

      # def initialize(config)
      #   @config = config
      # end

      # def build(transactions)
      #   reduced = transactions.each_with_object(
      #     transactions: {},
      #     traces: {}
      #   ) do |transaction, data|
      #     key = [
      #       transaction.name,
      #       transaction.result,
      #       transaction.timestamp
      #     ]

      #     if data[:transactions][key].nil?
      #       data[:transactions][key] = build_transaction(transaction)
      #     else
      #       data[:transactions][key][:durations] << ms(transaction.duration)
      #     end

      #     combine_traces transaction, transaction.traces, data[:traces]
      #   end.each_with_object({}) do |kv, data|
      #     key, collection = kv
      #     data[key] = collection.values
      #   end

      #   reduced[:traces].each do |trace|
      #     # traces' start time is average across collected
      #     trace[:start_time] =
      #       trace[:start_time].reduce(0, :+) / trace[:start_time].length
      #   end

      #   # preserve root
      #   root = reduced[:traces].shift
      #   # re-add root
      #   reduced[:traces].unshift root

      #   reduced
      # end

      # private

      # def combine_traces(transaction, traces, into)
      #   traces.each do |trace|
      #     key = [transaction.name, trace.name, trace.timestamp]

      #     if into[key].nil?
      #       into[key] = build_trace(transaction, trace)
      #     else
      #       into[key][:durations] << [
      #         ms(trace.duration),
      #         ms(transaction.duration)
      #       ]
      #       into[key][:start_time] << ms(trace.relative_start)
      #     end
      #   end
      # end

      # def build_transaction(transaction)
      #   {
      #     transaction: transaction.name,
      #     result: transaction.result,
      #     type: transaction.type,
      #     timestamp: transaction.timestamp,
      #     durations: [ms(transaction.duration)]
      #   }
      # end

      # def build_trace(transaction, trace)
      #   {
      #     transaction: transaction.name,
      #     name: trace.name,
      #     durations: [[
      #       ms(trace.duration),
      #       ms(transaction.duration)
      #     ]],
      #     start_time: [ms(trace.relative_start)],
      #     type: trace.type,
      #     timestamp: trace.timestamp,
      #     parents: trace.parents && trace.parents.map(&:name) || [],
      #     extra: trace.extra
      #   }
      # end
    end
  end
end
