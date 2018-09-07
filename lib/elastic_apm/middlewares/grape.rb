# frozen_string_literal: true

# Source: https://github.com/elastic/apm-agent-ruby/blob/master/lib/elastic_apm/middleware.rb
module ElasticAPM
  module Middlewares
    # @api private
    class Grape
      def initialize(app)
        @app = app
      end

      # rubocop:disable Metrics/MethodLength
      def call(env)
        begin
          transaction = ElasticAPM.transaction transaction_name(env), 'app',
            context: ElasticAPM.build_context(env)

          resp = @app.call env

          transaction.submit(resp[0], headers: resp[1]) if transaction
        rescue InternalError
          raise # Don't report ElasticAPM errors
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction.submit(500) if transaction
          raise
        ensure
          transaction.release if transaction
        end

        resp
      end
      # rubocop:enable Metrics/MethodLength

      private

      def transaction_name(env)
        request_method = env['REQUEST_METHOD']
        [request_method, grape_route_name(env)].join(' ')
      end

      # rubocop:disable Metrics/AbcSize
      # Pardon my safe navigation implementation to support ruby 2.2
      def grape_route_name(env)
        if env['api.endpoint'].respond_to?(:routes) &&
           env['api.endpoint'].routes.respond_to?(:first) &&
           env['api.endpoint'].routes.first.respond_to?(:pattern) &&
           env['api.endpoint'].routes.first.pattern.respond_to?(:origin)

          return env['api.endpoint'].routes.first.pattern.origin
        end

        env['REQUEST_PATH']
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
