# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class TransactionMetrics
      include Logging

      Transaction = Struct.new(duration, count)
      Update = Struct.new(duration, count)

      def initialize(config)
        @config = config
        @transactions = {}
      end

      attr_reader :config

      def collect
        # TODO
      end

      def update(updates)
        updates.each do |key, update|
          transaction = transactions[key]
          transaction.count += update.count
          transaction.duration += update.duration
        end
      end
    end
  end
end
