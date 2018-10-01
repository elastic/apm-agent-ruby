# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class ErrorSerializer < Serializer
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def build(error)
          base = {
            id: error.id,
            transaction_id: error.transaction_id,
            trace_id: error.trace_id,
            parent_id: error.parent_id,

            culprit: error.culprit,
            timestamp: micros_to_time(error.timestamp).utc.iso8601(3),
            context: error.context.to_h
          }

          if (exception = error.exception)
            base[:exception] = build_exception exception
          end

          if (log = error.log)
            base[:log] = build_log log
          end

          { error: base }
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        private

        def build_exception(exception)
          {
            message: exception.message,
            type: exception.type,
            module: exception.module,
            code: exception.code,
            attributes: exception.attributes,
            stacktrace: exception.stacktrace.to_a,
            handled: exception.handled
          }
        end

        def build_log(log)
          {
            message: log.message,
            level: log.level,
            logger_name: log.logger_name,
            param_message: log.param_message,
            stacktrace: log.stacktrace.to_a
          }
        end
      end
    end
  end
end
