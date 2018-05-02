# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Stacktrace
    attr_accessor :frames

    def length
      frames.length
    end

    def to_a
      frames.map(&:to_h)
    end
  end
end
