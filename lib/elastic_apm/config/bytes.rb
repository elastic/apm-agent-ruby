# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class Bytes
      MULTIPLIERS = {
        'kb' => 1024,
        'mb' => 1024 * 1_000,
        'gb' => 1024 * 100_000
      }.freeze
      REGEX = /^(\d+)(b|kb|mb|gb)?$/i.freeze

      def initialize(default_unit: 'kb')
        @default_unit = default_unit
      end

      def call(value)
        _, amount, unit = REGEX.match(String(value)).to_a
        unit ||= @default_unit
        MULTIPLIERS.fetch(unit.downcase, 1) * amount.to_i
      end
    end
  end
end
