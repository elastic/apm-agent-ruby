# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Middleware
    def initialize(app)
      @app = app
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
    def call(env)
      begin
        if running? && !path_ignored?(env)
          transaction = build_transaction(env)
        end

        resp = @app.call env

        submit_transaction(transaction, *resp) if transaction
      rescue InternalError
        raise # Don't report ElasticAPM errors
      rescue ::Exception => e
        ElasticAPM.report(e, handled: false)
        transaction.submit('HTTP 5xx', status: 500) if transaction
        raise
      ensure
        transaction.release if transaction
      end

      resp
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

    def submit_transaction(transaction, status, headers, _body)
      result = "HTTP #{status.to_s[0]}xx"
      transaction.submit(result, status: status, headers: headers)
    end

    def path_ignored?(env)
      config.ignore_url_patterns.any? do |r|
        env['PATH_INFO'].match r
      end
    end

    def build_transaction(env)
      ElasticAPM.transaction 'Rack', 'request',
        context: ElasticAPM.build_context(env)
    end

    def running?
      ElasticAPM.running?
    end

    def config
      ElasticAPM.agent.config
    end
  end
end
