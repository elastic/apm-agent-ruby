# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Traceparent
    class InvalidTraceparentHeader < StandardError; end

    VERSION = '00'
    REGEX = /
      (?<version>00)-
      (?<trace_id>[[:xdigit:]]{32})-
      (?<span_id>[[:xdigit:]]{16})-
      (?<flags>\d{2})
    /x

    def initialize
      @version = VERSION
    end

    def self.from_transaction(transaction)
      new.tap do |t|
        t.trace_id = SecureRandom.hex(16)
        t.span_id = transaction.id
        t.recorded = transaction.sampled?
        t.requested = transaction.sampled?
      end
    end

    def self.parse(header)
      unless (parts = REGEX.match(header))
        raise InvalidTraceparentHeader
      end

      new.tap do |t|
        t.header, t.version, t.trace_id, t.span_id, t.flags =
          Array(parts).tap do |values|
            values[-1] = Util.hex_to_bit(values[-1])
          end
      end
    end

    attr_accessor :header, :version, :trace_id, :span_id, :recorded, :requested

    alias :recorded? :recorded
    alias :requested? :requested

    def flags=(flags)
      @flags = flags

      self.recorded = flags[6] == '1'
      self.requested = flags[7] == '1'
    end

    def flags
      format('000000%d%d', recorded? ? 1 : 0, requested? ? 1 : 0)
    end

    def hex_flags
      format('%02x', flags.to_i(2))
    end

    def to_s
      format('%s-%s-%s-%s', version, trace_id, span_id, hex_flags)
    end
  end
end
