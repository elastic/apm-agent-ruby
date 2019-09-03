# frozen_string_literal: true

module ElasticAPM
  # @api private
  class TraceContext
    class InvalidTraceparentHeader < StandardError; end

    VERSION = '00'
    HEX_REGEX = /[^[:xdigit:]]/.freeze

    TRACE_ID_LENGTH = 16
    ID_LENGTH = 8

    def initialize(
      version: VERSION,
      trace_id: nil,
      span_id: nil,
      id: nil,
      recorded: true
    )
      @version = version
      @trace_id = trace_id || hex(TRACE_ID_LENGTH)
      # TODO: rename to parent_id with next major version bump
      @parent_id = span_id
      @id = id || hex(ID_LENGTH)
      @recorded = recorded
    end

    attr_accessor :version, :id, :trace_id, :parent_id, :recorded

    alias :recorded? :recorded

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
      @parent_id ||= hex(ID_LENGTH)
    end

    def child
      dup.tap do |tc|
        tc.parent_id = tc.id
        tc.id = hex(ID_LENGTH)
      end
    end

    def to_header
      format('%s-%s-%s-%s', version, trace_id, id, hex_flags)
    end

    private

    def hex(len)
      SecureRandom.hex(len)
    end
  end
end
