# frozen_string_literal: true

module ElasticAPM
  module Normalizers
    module Grape
      # @api private
      class EndpointRun < Normalizer
        register 'endpoint_run.grape'

        TYPE = 'app'
        SUBTYPE = 'resource'

        def normalize(transaction, _name, payload)
          transaction.name = endpoint(payload[:env])
          [transaction.name, TYPE, SUBTYPE, nil, nil]
        end

        private

        def endpoint(env)
          route_name = env['api.endpoint']&.routes&.first&.pattern&.origin || env['REQUEST_PATH']
          [env['REQUEST_METHOD'], route_name].join(' ')
        end
      end

      class Filters < EndpointRun
        register 'endpoint_run_filters.grape'

        TYPE = 'filter'

        def normalize(transaction, _name, payload)
          transaction.name = endpoint(payload[:endpoint].env)
          [transaction.name, TYPE, payload[:type], nil, nil]
        end
      end

      class Validators < EndpointRun
        register 'endpoint_run_validators.grape'

        TYPE = 'validator'

        def normalize(transaction, _name, payload)
          transaction.name = endpoint(payload[:endpoint].env)
          [transaction.name, TYPE, nil, nil, nil]
        end
      end
    end
  end
end
