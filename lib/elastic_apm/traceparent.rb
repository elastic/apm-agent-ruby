# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Traceparent
    class InvalidTraceparentHeader < StandardError; end

    VERSION = '00'
    HEX_REGEX = /[^[:xdigit:]]/

    def initialize
      @version = VERSION
    end

    def self.from_transaction(transaction)
      new.tap do |t|
        t.trace_id = SecureRandom.hex(16)
        t.recorded = transaction.sampled?
      end
    end

    # rubocop:disable Metrics/AbcSize
    def self.parse(header)
      raise InvalidTraceparentHeader unless header.length == 55
      raise InvalidTraceparentHeader unless header[0..1] == VERSION

      new.tap do |t|
        t.version, t.trace_id, t.span_id, t.flags =
          header.split('-').tap do |values|
            values[-1] = Util.hex_to_bits(values[-1])
          end

        raise InvalidTraceparentHeader if HEX_REGEX =~ t.trace_id
        raise InvalidTraceparentHeader if HEX_REGEX =~ t.span_id
      end
    end
    # rubocop:enable Metrics/AbcSize

    attr_accessor :header, :version, :trace_id, :span_id, :recorded

    alias :recorded? :recorded

    def flags=(flags)
      @flags = flags

      self.recorded = flags[7] == '1'
    end

    def flags
      format('0000000%d', recorded? ? 1 : 0)
    end

    def hex_flags
      format('%02x', flags.to_i(2))
    end

    def to_header(span_id: nil)
      span_id ||= self.span_id
      format('%s-%s-%s-%s', version, trace_id, span_id, hex_flags)
    end
  end
end
