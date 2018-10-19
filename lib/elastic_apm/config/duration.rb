# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class Duration
      MULTIPLIERS = { 'ms' => 0.001, 'm' => 60 }.freeze
      REGEX = /^(-)?(\d+)(m|ms|s)?$/i

      def initialize(minutes)
        @minutes = minutes
      end

      attr_accessor :minutes

      def self.parse(str, default_unit:)
        _, negative, amount, unit = REGEX.match(str).to_a
        unit ||= default_unit
        minutes = MULTIPLIERS.fetch(unit.downcase, 1) * amount.to_i
        minutes = 0 - minutes if negative
        new(minutes)
      end
    end
  end
end
