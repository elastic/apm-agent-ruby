#
# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Middleware
    include Logging

    def initialize(app)
      @app = app
    end

    def call(env)
      begin
        if running? && !path_ignored?(env)
          transaction = start_transaction(env)
        end

        resp = @app.call env
      rescue InternalError
        raise # Don't report ElasticAPM errors
      rescue ::Exception => e
        context = ElasticAPM.build_context(rack_env: env, for_type: :error)
        ElasticAPM.report(e, context: context, handled: false)
        raise
      ensure
        if resp && transaction
          status, headers, _body = resp
          transaction.add_response(status, headers: headers.dup)
        end

        ElasticAPM.end_transaction http_result(status)
      end

      resp
    end

    private

    def http_result(status)
      status && "HTTP #{status.to_s[0]}xx"
    end

    def path_ignored?(env)
      config.ignore_url_patterns.any? do |r|
        env['PATH_INFO'].match r
      end
    end

    def start_transaction(env)
      context = ElasticAPM.build_context(rack_env: env, for_type: :transaction)

      ElasticAPM.start_transaction 'Rack', 'request',
        context: context,
        trace_context: trace_context(env)
    end

    def trace_context(env)
      return unless (header = get_traceparent_header(env))

      TraceContext.parse(header).tap do |tc|
        next unless (header = env['HTTP_TRACESTATE'])
        tc.tracestate = TraceContext::Tracestate.parse(header)
      end
    rescue TraceContext::InvalidTraceparentHeader
      warn "Couldn't parse invalid traceparent header: #{header.inspect}"
      nil
    end

    def get_traceparent_header(env)
      if (header = env['HTTP_ELASTIC_APM_TRACEPARENT'])
        return header
      end

      if (header = env['HTTP_TRACEPARENT'])
        return header
      end

      nil
    end

    def running?
      ElasticAPM.running?
    end

    def config
      @config ||= ElasticAPM.agent.config
    end
  end
end
