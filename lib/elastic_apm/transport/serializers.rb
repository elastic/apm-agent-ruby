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

        attr_reader :config

        private

        def ms(micros)
          micros.to_f / 1_000
        end

        def keyword_field(value)
          Util.truncate(value)
        end

        def keyword_object(hash)
          return unless hash

          hash.tap do |h|
            h.each { |k, v| hash[k] = keyword_field(v) }
          end
        end
      end

      # @api private
      class Container
        def initialize(config)
          @transaction = Serializers::TransactionSerializer.new(config)
          @span = Serializers::SpanSerializer.new(config)
          @error = Serializers::ErrorSerializer.new(config)
          @metadata = Serializers::MetadataSerializer.new(config)
          @metricset = Serializers::MetricsetSerializer.new(config)
        end

        attr_reader :transaction, :span, :error, :metadata, :metricset

        # rubocop:disable Metrics/MethodLength
        def serialize(resource)
          case resource
          when Transaction
            transaction.build(resource)
          when Span
            span.build(resource)
          when Error
            error.build(resource)
          when Metricset
            metricset.build(resource)
          when Metadata
            metadata.build(resource)
          else
            raise UnrecognizedResource, resource.inspect
          end
        end
        # rubocop:enable Metrics/MethodLength
      end

      def self.new(config)
        Container.new(config)
      end
    end
  end
end

require 'elastic_apm/transport/serializers/context_serializer'
require 'elastic_apm/transport/serializers/transaction_serializer'
require 'elastic_apm/transport/serializers/span_serializer'
require 'elastic_apm/transport/serializers/error_serializer'
require 'elastic_apm/transport/serializers/metricset_serializer'
require 'elastic_apm/transport/serializers/metadata_serializer'
