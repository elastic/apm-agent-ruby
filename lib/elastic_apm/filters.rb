# frozen_string_literal: true

require 'elastic_apm/filters/request_body_filter'
require 'elastic_apm/filters/secrets_filter'

module ElasticAPM
  # @api private
  module Filters
    def self.new(config)
      Container.new(config)
    end

    # @api private
    class Container
      def initialize(config)
        @config = config
        @filters = {
          request_body: RequestBodyFilter.new(config),
          secrets: SecretsFilter.new(config)
        }
      end

      attr_reader :config, :filters

      def add(key, filter)
        @filters[key] = filter
      end

      def remove(key)
        @filters.delete(key)
      end

      def apply(payload)
        @filters.reduce(payload) do |result, (_key, filter)|
          filter.call(result)
        end
      end
    end
  end
end
