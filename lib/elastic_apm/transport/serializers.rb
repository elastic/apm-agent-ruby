# frozen_string_literal: true

require 'json'

module ElasticAPM
  module Transport
    # @api private
    module Serializers
      # @api private
      class Serializer
        def initialize(config)
          @config = config
        end

        private

        def micros_to_time(micros)
          Time.at(ms(micros) / 1_000)
        end

        def ms(micros)
          micros.to_f / 1_000
        end
      end
    end
  end
end

require 'elastic_apm/transport/serializers/transaction_serializer'
require 'elastic_apm/transport/serializers/span_serializer'
require 'elastic_apm/transport/serializers/error_serializer'
