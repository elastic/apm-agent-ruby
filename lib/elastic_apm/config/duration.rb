# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class Duration
      MULTIPLIERS = { 'ms' => 0.001, 'm' => 60 }.freeze
      REGEX = /^(-)?(\d+)(m|ms|s)?$/i.freeze

      def initialize(default_unit: 's')
        @default_unit = default_unit
      end

      def call(str)
        _, negative, amount, unit = REGEX.match(String(str)).to_a
        unit ||= @default_unit
        seconds = MULTIPLIERS.fetch(unit.downcase, 1) * amount.to_i
        seconds = 0 - seconds if negative
        seconds
      end
    end
  end
end
