# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Errors < Serializer
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build(error)
        base = {
          id: error.id,
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

        if (transaction_id = error.transaction_id)
          base[:transaction] = { id: transaction_id }
        end

        base
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def build_all(errors)
        { errors: Array(errors).map { |e| build(e) } }
      end

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
