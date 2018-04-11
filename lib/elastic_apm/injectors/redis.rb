# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class RedisInjector
      def install
        ::Redis::Client.class_eval do
          alias call_without_apm call

          def call(command, &block)
            name = command[0].upcase

            return call_without_apm(command, &block) if command[0] == :auth

            ElasticAPM.span(name.to_s, 'db.redis') do
              call_without_apm(command, &block)
            end
          end
        end
      end
    end

    register 'Redis', 'redis', RedisInjector.new
  end
end
