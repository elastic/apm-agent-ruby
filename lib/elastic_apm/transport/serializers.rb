# frozen_string_literal: true

module ElasticAPM
  module Transport
    # @api private
    module Serializers
      # @api private
      class UnrecognizedResource < InternalError; end

      # @api private
      class Serializer

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

        def mixed_object(hash)
          return unless hash

          hash.tap do |h|
            h.each do |k, v|
              hash[k] = v.is_a?(String) ? keyword_field(v) : v
            end
          end
        end
      end

      # @api private
      class Container
        def initialize
          @transaction = Serializers::TransactionSerializer.new
          @span = Serializers::SpanSerializer.new
          @error = Serializers::ErrorSerializer.new
          @metadata = Serializers::MetadataSerializer.new
          @metricset = Serializers::MetricsetSerializer.new
        end

        attr_reader :transaction, :span, :error, :metadata, :metricset
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
      end

      def self.new
        Container.new
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
