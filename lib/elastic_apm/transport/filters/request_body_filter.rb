# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Filters
      # @api private
      class RequestBodyFilter
        FILTERED = '[FILTERED]'

        def initialize(config)
          @config = config
        end

        def call(payload)
          strip_body_from payload[:transaction]
          strip_body_from payload[:error]

          payload
        end

        private

        def strip_body_from(payload)
          return unless payload
          return unless (request = payload.dig(:context, :request))
          request[:body] = FILTERED
        end
      end
    end
  end
end
