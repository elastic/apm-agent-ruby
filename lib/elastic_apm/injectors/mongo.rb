# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class MongoInjector
      def install
        ::Mongo::Monitoring::Global.subscribe(
          ::Mongo::Monitoring::COMMAND,
          Subscriber.new
        )
      end

      # @api private
      class Subscriber
        TYPE = 'db.mongodb.query'.freeze

        def initialize
          @events = {}
        end

        def started(event)
          push_event(event)
        end

        def failed(event)
          pop_event(event)
        end

        def succeeded(event)
          pop_event(event)
        end

        private

        def push_event(event)
          ctx = Span::Context.new(
            instance: event.database_name,
            statement: nil,
            type: 'mongodb'.freeze,
            user: nil
          )
          span = ElasticAPM.span(event.command_name, TYPE, context: ctx)
          @events[event.operation_id] = span
        end

        def pop_event(event)
          span = @events[event.operation_id]
          span.done
        end
      end
    end

    register 'Mongo', 'mongo', MongoInjector.new
  end
end
