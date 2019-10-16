# frozen_string_literal: true

module ElasticAPM
  module Normalizers
    module Grape
      # @api private
      class EndpointRun < Normalizer
        register 'endpoint_run.grape'

        TYPE = 'app'
        SUBTYPE = 'resource'

        FRAMEWORK_NAME = 'Grape'

        def normalize(transaction, _name, payload)
          transaction.name = endpoint(payload[:env])
          unless transaction.config.framework_name == FRAMEWORK_NAME
            transaction.context.set_service(framework_name: FRAMEWORK_NAME,
                                            framework_version: ::Grape::VERSION)
          end
          [transaction.name, TYPE, SUBTYPE, nil, nil]
        end

        private

        def endpoint(env)
          route_name = env['api.endpoint']&.routes&.first&.pattern&.origin ||
            env['REQUEST_PATH']
          [env['REQUEST_METHOD'], route_name].join(' ')
        end
      end
    end
  end
end
