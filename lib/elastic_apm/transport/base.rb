# frozen_string_literal: true

require 'elastic_apm/transport/connection'
require 'elastic_apm/transport/serializers'
require 'elastic_apm/transport/filters'

module ElasticAPM
  module Transport
    class UnrecognizedResource < InternalError; end

    # @api private
    class Base
      # rubocop:disable Metrics/MethodLength
      def initialize(config)
        @config = config

        @connection = Connection.new(
          intake_url,
          max_request_time: config.api_request_time,
          max_request_size: config.api_request_size
        )

        @serializers = Struct.new(:transaction, :span, :error).new(
          Serializers::TransactionSerializer.new(config),
          Serializers::SpanSerializer.new(config),
          Serializers::ErrorSerializer.new(config)
        )

        @filters = Filters.new(config)
      end
      # rubocop:enable Metrics/MethodLength

      attr_reader :config, :filters, :connection

      # rubocop:disable Metrics/MethodLength
      def submit(resource)
        serialized =
          case resource
          when Transaction
            @serializers.transaction.build(resource)
          when Span
            @serializers.span.build(resource)
          when Error
            @serializers.error.build(resource)
          else
            raise UnrecognizedResource
          end

        post serialized
      end
      # rubocop:enable Metrics/MethodLength

      def post(payload)
        @filters.apply payload
        @connection.write(payload.to_json) unless config.disable_send?
      end

      def close!
        @connection.close!
      end

      private

      def intake_url
        config.server_url + '/v2/intake'
      end
    end
  end
end
