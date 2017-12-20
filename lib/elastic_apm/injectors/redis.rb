# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class RedisInjector
      # rubocop:disable Metrics/MethodLength
      def install
        ::Redis::Client.class_eval do
          alias call_without_apm call

          def call(command, &block)
            name = command[0].upcase
            statement =
              format('%s %s', name, command[1..command.length].join(' '))
            context = Span::Context.new(
              statement: statement,
              type: 'redis'
            )

            ElasticAPM.span(name.to_s, 'db.redis', context: context) do
              call_without_apm(command, &block)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    register 'Redis', 'redis', RedisInjector.new
  end
end
