#
# frozen_string_literal: true

require 'elastic_apm/traceparent'

module ElasticAPM
  # @api private
  class Middleware
    include Logging

    def initialize(app)
      @app = app
    end

    # rubocop:disable Metrics/MethodLength
    def call(env)
      begin
        if running? && !path_ignored?(env)
          transaction = start_transaction(env)
        end

        resp = @app.call env
      rescue InternalError
        raise # Don't report ElasticAPM errors
      rescue ::Exception => e
        ElasticAPM.report(e, handled: false)
        raise
      ensure
        if resp && transaction
          status, headers, _body = resp
          transaction.add_response(status, headers: headers)
        end

        ElasticAPM.end_transaction http_result(status)
      end

      resp
    end
    # rubocop:enable Metrics/MethodLength

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
      ElasticAPM.start_transaction 'Rack', 'request',
        context: ElasticAPM.build_context(env),
        traceparent: traceparent(env)
    end

    def traceparent(env)
      return unless (header = env['HTTP_ELASTIC_APM_TRACEPARENT'])
      Traceparent.parse(header)
    rescue Traceparent::InvalidTraceparentHeader
      warn "Couldn't parse invalid traceparent header: #{header.inspect}"
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
