# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Filters
      # @api private
      class SecretsFilter
        FILTERED = '[FILTERED]'

        KEY_FILTERS = [
          /passw(or)?d/i,
          /auth/i,
          /^pw$/,
          /secret/i,
          /token/i,
          /api[-._]?key/i,
          /session[-._]?id/i
        ].freeze

        VALUE_FILTERS = [
          # (probably) credit card number
          /^\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}$/
        ].freeze

        def initialize(config)
          @config = config
          @key_filters = KEY_FILTERS + config.custom_key_filters
        end

        def call(payload)
          strip_from payload[:transaction], :context, :request, :headers
          strip_from payload[:transaction], :context, :response, :headers
          strip_from payload[:error], :context, :request, :headers
          strip_from payload[:error], :context, :response, :headers

          payload
        end

        def strip_from(event, *path)
          return unless event
          return unless (headers = event.dig(*path))

          headers.each do |k, v|
            if filter_key?(k) || filter_value?(v)
              headers[k] = FILTERED
            end
          end
        end

        def filter_key?(key)
          @key_filters.any? { |regex| key.match regex }
        end

        def filter_value?(value)
          VALUE_FILTERS.any? { |regex| value.match regex }
        end
      end
    end
  end
end
