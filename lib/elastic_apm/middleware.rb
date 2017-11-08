# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      begin
        transaction = ElasticAPM.transaction 'Rack', 'request'
        resp = @app.call env
        transaction.submit resp[0]
      ensure
        transaction.release if transaction
      end

      resp
    end
  end
end
