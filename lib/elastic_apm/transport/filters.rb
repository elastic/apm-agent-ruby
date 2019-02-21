# frozen_string_literal: true

require 'elastic_apm/transport/filters/secrets_filter'

module ElasticAPM
  module Transport
    # @api private
    module Filters
      def self.new(config)
        Container.new(config)
      end

      # @api private
      class Container
        def initialize(config)
          @filters = { secrets: SecretsFilter.new(config) }
        end

        def add(key, filter)
          @filters[key] = filter
        end

        def remove(key)
          @filters.delete(key)
        end

        def apply!(payload)
          @filters.reduce(payload) do |result, (_key, filter)|
            result = filter.call(result)
            break if result.nil?
            result
          end
        end

        def length
          @filters.length
        end
      end
    end
  end
end
