# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class Duration
      MULTIPLIERS = { 'ms' => 0.001, 'm' => 60 }.freeze
      REGEX = /^(-)?(\d+)(m|ms|s)?$/i.freeze

      def initialize(seconds)
        @seconds = seconds
      end

      attr_accessor :seconds

      def self.parse(str, default_unit:)
        _, negative, amount, unit = REGEX.match(str).to_a
        unit ||= default_unit
        seconds = MULTIPLIERS.fetch(unit.downcase, 1) * amount.to_i
        seconds = 0 - seconds if negative
        new(seconds)
      end
    end
  end
end
