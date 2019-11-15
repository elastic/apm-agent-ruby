# frozen_string_literal: true

module ElasticAPM
  module Metrics
    # @api private
    class BreakdownSet < SpanScopedSet
      def initialize(config)
        super

        disable! unless config.breakdown_metrics?
      end
    end
  end
end
