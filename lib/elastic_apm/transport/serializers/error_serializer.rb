# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class ErrorSerializer < Serializer
        def context_serializer
          @context_serializer ||= ContextSerializer.new(config)
        end

        def build(error)
          base = {
            id: error.id,
            transaction_id: error.transaction_id,
            transaction: build_transaction(error.transaction),
            trace_id: error.trace_id,
            parent_id: error.parent_id,

            culprit: keyword_field(error.culprit),
            timestamp: error.timestamp
          }

          if (context = context_serializer.build(error.context))
            base[:context] = context
          end

          if (exception = error.exception)
            base[:exception] = build_exception exception
          end

          if (log = error.log)
            base[:log] = build_log log
          end

          { error: base }
        end

        private

        def build_exception(exception)
          {
            message: exception.message,
            type: keyword_field(exception.type),
            module: keyword_field(exception.module),
            code: keyword_field(exception.code),
            attributes: exception.attributes,
            stacktrace: exception.stacktrace.to_a,
            handled: exception.handled,
            cause: exception.cause && [build_exception(exception.cause)]
          }
        end

        def build_log(log)
          {
            message: log.message,
            level: keyword_field(log.level),
            logger_name: keyword_field(log.logger_name),
            param_message: keyword_field(log.param_message),
            stacktrace: log.stacktrace.to_a
          }
        end

        def build_transaction(transaction)
          return unless transaction

          {
            sampled: transaction[:sampled],
            type: keyword_field(transaction[:type])
          }
        end
      end
    end
  end
end
