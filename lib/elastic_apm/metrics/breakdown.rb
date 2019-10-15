# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class SpanScopedSet < Set
      include Logging

      def collect
        result = super
        result.each do |set|
          move_transaction(set)
          move_span(set)
        end
        result
      end

      private

      def move_transaction(set)
        name = set.tags&.delete(:'transaction.name')
        type = set.tags&.delete(:'transaction.type')
        return unless name || type

        set.transaction = { name: name, type: type }
      end

      def move_span(set)
        type = set.tags&.delete(:'span.type')
        subtype = set.tags&.delete(:'span.subtype')
        return unless type

        set.span = { type: type, subtype: subtype }
      end
    end

    class Breakdown < SpanScopedSet
    end

    class Transaction < SpanScopedSet
    end
  end
end
