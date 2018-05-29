# frozen_string_literal: true

module ElasticAPM
  module Filters
    # @api private
    class SecretsFilter
      FILTERED = '[FILTERED]'.freeze

      KEY_FILTERS = [
        /passw(or)?d/i,
        /^pw$/,
        /secret/i,
        /token/i,
        /api[-._]?key/i,
        /session[-._]?id/i
      ].freeze

      VALUE_FILTERS = [
        /^\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}$/ # (probably) credit card number
      ].freeze

      def initialize(config)
        @config = config
        @key_filters = KEY_FILTERS + config.custom_key_filters
      end

      def call(payload)
        strip_from payload[:transactions], :context, :request, :headers
        strip_from payload[:transactions], :context, :response, :headers
        strip_from payload[:errors], :context, :request, :headers
        strip_from payload[:errors], :context, :response, :headers

        payload
      end

      def strip_from(events, *path)
        return unless events

        events.each do |event|
          next unless (headers = event.dig(*path))

          headers.each do |k, v|
            if filter_key?(k) || filter_value?(v)
              headers[k] = FILTERED
            end
          end
        end
      end

      def filter_key?(key)
        @key_filters.any? { |regex| key =~ regex }
      end

      def filter_value?(value)
        VALUE_FILTERS.any? { |regex| value =~ regex }
      end
    end
  end
end
