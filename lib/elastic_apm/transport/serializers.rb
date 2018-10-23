# frozen_string_literal: true

require 'json'

module ElasticAPM
  module Transport
    # @api private
    module Serializers
      # @api private
      class UnrecognizedResource < InternalError; end

      # @api private
      class Serializer
        def initialize(config)
          @config = config
        end

        private

        def ms(micros)
          micros.to_f / 1_000
        end
      end

      # @api private
      class Container
        def initialize(config)
          @transaction = Serializers::TransactionSerializer.new(config)
          @span = Serializers::SpanSerializer.new(config)
          @error = Serializers::ErrorSerializer.new(config)
        end

        attr_reader :transaction, :span, :error

        def serialize(resource)
          case resource
          when Transaction
            transaction.build(resource)
          when Span
            span.build(resource)
          when Error
            error.build(resource)
          else
            raise UnrecognizedResource, resource.inspect
          end
        end
      end

      def self.new(config)
        Container.new(config)
      end
    end
  end
end

require 'elastic_apm/transport/serializers/transaction_serializer'
require 'elastic_apm/transport/serializers/span_serializer'
require 'elastic_apm/transport/serializers/error_serializer'
