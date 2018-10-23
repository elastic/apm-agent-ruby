# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class Size
      MULTIPLIERS = {
        'kb' => 1024,
        'mb' => 1024 * 1_000,
        'gb' => 1024 * 100_000
      }.freeze
      REGEX = /^(\d+)(b|kb|mb|gb)?$/i.freeze

      def initialize(bytes)
        @bytes = bytes
      end

      attr_accessor :bytes

      def self.parse(str, default_unit:)
        _, amount, unit = REGEX.match(str).to_a
        unit ||= default_unit
        bytes = MULTIPLIERS.fetch(unit.downcase, 1) * amount.to_i
        new(bytes)
      end
    end
  end
end
