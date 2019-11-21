# frozen_string_literal: true

require 'elastic_apm/transport/filters/secrets_filter'

module ElasticAPM
  module Transport
    # @api private
    module Filters
      SKIP = :skip
      LOCK = Mutex.new

      def self.new(config)
        Container.new(config)
      end

      # @api private
      class Container
        def initialize(config)
          @filters = { secrets: SecretsFilter.new(config) }
        end

        def add(key, filter)
          LOCK.synchronize do
            @filters[key] = filter
          end
        end

        def remove(key)
          @filters.delete(key)
        end

        def apply!(payload)
          LOCK.synchronize do
            @filters.reduce(payload) do |result, (_key, filter)|
              result = filter.call(result)
              break SKIP if result.nil?
              result
            end
          end
        end

        def length
          @filters.length
        end
      end
    end
  end
end
