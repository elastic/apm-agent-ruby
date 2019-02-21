# frozen_string_literal: true

module ElasticAPM
  # @api private
  class TraceContext
    class InvalidTraceparentHeader < StandardError; end

    VERSION = '00'
    HEX_REGEX = /[^[:xdigit:]]/.freeze

    TRACE_ID_N = 16
    ID_N = 8

    def initialize(
      version: VERSION,
      trace_id: nil,
      span_id: nil,
      id: nil,
      recorded: true
    )
      @version = version
      @trace_id = trace_id || hex_id(TRACE_ID_N)
      @parent_id = span_id # rename to parent_id with next major version bump
      @id = id || hex_id(ID_N)
      @recorded = recorded
    end

    attr_accessor :version, :id, :trace_id, :parent_id, :recorded

    alias :recorded? :recorded

    def self.for_transaction(sampled: true)
      new(recorded: sampled)
    end

    # rubocop:disable Metrics/AbcSize
    def self.parse(header)
      raise InvalidTraceparentHeader unless header.length == 55
      raise InvalidTraceparentHeader unless header[0..1] == VERSION

      new.tap do |t|
        t.version, t.trace_id, t.parent_id, t.flags =
          header.split('-').tap do |values|
            values[-1] = Util.hex_to_bits(values[-1])
          end

        raise InvalidTraceparentHeader if HEX_REGEX =~ t.trace_id
        raise InvalidTraceparentHeader if HEX_REGEX =~ t.parent_id
      end
    end
    # rubocop:enable Metrics/AbcSize

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

    def ensure_parent_id
      @parent_id ||= hex_id(ID_N)
      @parent_id
    end

    def child
      dup.tap do |tc|
        tc.parent_id = tc.id
        tc.id = hex_id(ID_N)
      end
    end

    def to_header
      format('%s-%s-%s-%s', version, trace_id, id, hex_flags)
    end

    # @deprecated Use parent_id instead
    def span_id
      @parent_id
    end

    # @deprecated Use parent_id instead
    def span_id=(span_id)
      @parent_id = span_id
    end

    private

    def hex_id(len)
      SecureRandom.hex(len)
    end
  end
end
