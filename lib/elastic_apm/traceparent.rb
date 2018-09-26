# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Traceparent
    VERSION = '00'

    def self.from_transaction(transaction)
      new.tap do |t|
        t.version = VERSION
        t.trace_id = SecureRandom.hex(16)
        t.span_id = transaction.id
        t.recorded = transaction.sampled?
        t.requested = transaction.sampled?
      end
    end

    # rubocop:disable Metrics/AbcSize
    def self.parse(header)
      new.tap do |t|
        t.header = header
        t.version, t.trace_id, t.span_id, t.flags =
          header.split('-').tap do |values|
            values[-1] = Util.hex_to_bit(values[-1])
          end
        t.recorded = t.flags[6] == '1'
        t.requested = t.flags[7] == '1'
      end
    end
    # rubocop:enable Metrics/AbcSize

    attr_accessor :header, :version, :trace_id, :span_id, :recorded, :requested,
      :flags

    alias :recorded? :recorded
    alias :requested? :requested

    def valid?
      return false unless version == VERSION
      return false unless trace_id =~ /[^[:xdigit:]]/
      return false unless span_id =~ /[^[:xdigit:]]/

      true
    end
  end
end
