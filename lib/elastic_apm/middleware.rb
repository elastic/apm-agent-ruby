# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Middleware
    def initialize(app)
      @app = app
    end

    # rubocop:disable Metrics/MethodLength
    def call(env)
      begin
        transaction = ElasticAPM.transaction 'Rack', 'request'
        resp = @app.call env
        transaction.submit(resp[0]) if transaction
      rescue InternalError
        raise # Don't report ElasticAPM errors
      rescue ::Exception => e
        ElasticAPM.report(e, rack_env: env, handled: false)
        transaction.submit(500) if transaction
        raise
      ensure
        transaction.release if transaction
      end

      resp
    end
    # rubocop:enable Metrics/MethodLength
  end
end
