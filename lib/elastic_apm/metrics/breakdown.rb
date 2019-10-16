# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class SpanScopedSet < Set
      def collect
        super.tap do |sets|
          return unless sets

          sets.each do |set|
            move_transaction(set)
            move_span(set)
          end
        end
      end

      private

      def move_transaction(set)
        name = set.tags&.delete(:'transaction.name')
        type = set.tags&.delete(:'transaction.type')
        return unless name || type

        set.transaction = { name: name, type: type }
        set.tags = nil if set.tags.empty?
      end

      def move_span(set)
        type = set.tags&.delete(:'span.type')
        subtype = set.tags&.delete(:'span.subtype')
        return unless type

        set.span = { type: type, subtype: subtype }
        set.tags = nil if set.tags.empty?
      end
    end

    # @api private
    class Breakdown < SpanScopedSet
      def initialize(config)
        super

        disable! unless config.breakdown_metrics?
      end
    end

    # @api private
    class Transaction < SpanScopedSet
    end
  end
end
