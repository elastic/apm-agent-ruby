# frozen_string_literal: true

module ElasticAPM
  module Filters
    # @api private
    class RequestBodyFilter
      FILTERED = '[FILTERED]'.freeze

      def initialize(config)
        @config = config
      end

      def call(payload)
        strip_body_from payload[:transactions]
        strip_body_from payload[:errors]

        payload
      end

      private

      def strip_body_from(arr)
        return unless arr

        arr.each do |entity|
          next unless (request = entity.dig(:context, :request))

          request[:body] = FILTERED
        end
      end
    end
  end
end
