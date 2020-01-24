# frozen_string_literal: true

require 'elastic_apm/trace_context/tracestate'
require 'elastic_apm/trace_context/traceparent'

module ElasticAPM
  # @api private
  class TraceContext
    class InvalidTraceparentHeader < StandardError; end

    def initialize(
      traceparent: nil,
      tracestate: nil,
      **legacy_traceparent_attrs
    )
      @traceparent = traceparent || Traceparent.new(**legacy_traceparent_attrs)
      @tracestate = tracestate
    end

    attr_accessor :traceparent, :tracestate

    def self.parse(legacy_header = nil, env: nil)
      if !legacy_header && !env
        raise ArgumentError, 'TraceContext expects either env: or single ' \
          'argument header string'
      end

      if legacy_header
        return legacy_parse_from_header(legacy_header)
      end

      return unless (header = get_traceparent_header(env))

      parent = TraceContext::Traceparent.parse(header)

      state =
        if (header = env['HTTP_TRACESTATE'])
          TraceContext::Tracestate.parse(header)
        end

      new(traceparent: parent, tracestate: state)
    end

    def self.legacy_parse_from_header(header)
      parent = Traceparent.parse(header)
      new(traceparent: parent)
    end

    def version
      traceparent.version
    end

    def trace_id
      traceparent.trace_id
    end

    def id
      traceparent.id
    end

    def parent_id
      traceparent.parent_id
    end

    def ensure_parent_id
      traceparent.ensure_parent_id
    end

    def recorded?
      traceparent.recorded?
    end

    def child
      dup.tap do |tc|
        tc.traceparent = tc.traceparent.child
      end
    end

    def apply_headers
      yield 'Traceparent', traceparent.to_header

      if tracestate
        yield 'Tracestate', tracestate.to_header
      end

      return unless ElasticAPM.agent.config.use_elastic_traceparent_header

      yield 'Elastic-Apm-Traceparent', traceparent.to_header
    end

    class << self
      private

      def get_traceparent_header(env)
        if (header = env['HTTP_ELASTIC_APM_TRACEPARENT'])
          return header
        end

        if (header = env['HTTP_TRACEPARENT'])
          return header
        end

        nil
      end
    end
  end
end
