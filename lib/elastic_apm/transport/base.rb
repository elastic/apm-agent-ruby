# frozen_string_literal: true

require 'elastic_apm/transport/connection'
require 'elastic_apm/transport/serializers'
require 'elastic_apm/transport/filters'

require 'elastic_apm/metadata/service_info'
require 'elastic_apm/metadata/system_info'
require 'elastic_apm/metadata/process_info'

module ElasticAPM
  module Transport
    class UnrecognizedResource < InternalError; end

    # @api private
    class Base
      def initialize(config)
        @config = config

        @connection = Connection.new(config)

        @serializers = Struct.new(:transaction, :span, :error).new(
          Serializers::TransactionSerializer.new(config),
          Serializers::SpanSerializer.new(config),
          Serializers::ErrorSerializer.new(config)
        )

        @filters = Filters.new(config)
      end

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

      def flush
        @connection.close!
      end
    end
  end
end
