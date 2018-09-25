# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Traceparent
    def initialize(header)
      @header = header
      @version, @trace_id, @span_id, @flags = parse(header)
    end

    attr_reader :header, :version, :trace_id, :span_id, :flags

    def recorded?
      flags[6] == '1'
    end

    def requested?
      flags[7] == '1'
    end

    private

    def parse(header)
      values = header.split('-')
      values[-1] = hex_to_bit(values[-1])
      values
    end

    def hex_to_bit(str)
      str.hex.to_s(2).rjust(str.size * 4, '0')
    end
  end
end
