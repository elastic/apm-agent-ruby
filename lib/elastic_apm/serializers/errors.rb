# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Errors < Serializer
      # rubocop:disable Metrics/MethodLength
      def build(error)
        base = {
          id: error.id,
          culprit: error.culprit,
          timestamp: micros_to_time(error.timestamp).utc.iso8601
        }

        if (exception = error.exception)
          base[:exception] = build_exception exception
        end

        if (transaction_id = error.transaction_id)
          base[:transaction] = { id: transaction_id }
        end

        base
      end
      # rubocop:enable Metrics/MethodLength

      def build_all(errors)
        { errors: Array(errors).map(&method(:build)) }
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
    end
  end
end
