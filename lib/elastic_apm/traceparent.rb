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

    def self.from_transaction(transaction)
      new.tap do |t|
        t.version = VERSION
        t.trace_id = SecureRandom.hex(16)
        t.span_id = transaction.id
        t.recorded = transaction.sampled?
        t.requested = transaction.sampled?
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def self.parse(header)
      unless (parts = REGEX.match(header))
        raise InvalidTraceparentHeader
      end

      new.tap do |t|
        t.header, t.version, t.trace_id, t.span_id, t.flags =
          Array(parts).tap do |values|
            values[-1] = Util.hex_to_bit(values[-1])
          end
        t.recorded = t.flags[6] == '1'
        t.requested = t.flags[7] == '1'
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    attr_accessor :header, :version, :trace_id, :span_id, :recorded, :requested,
      :flags

    alias :recorded? :recorded
    alias :requested? :requested
  end
end
