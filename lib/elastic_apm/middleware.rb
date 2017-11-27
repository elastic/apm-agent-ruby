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
        transaction&.submit(resp[0])
      rescue InternalError
        raise # Don't report ElasticAPM errors
      rescue ::Exception => e
        ElasticAPM.report(e, rack_env: env)
        transaction&.submit(500)
        raise
      ensure
        transaction&.release
      end

      resp
    end
    # rubocop:enable Metrics/MethodLength
  end
end
