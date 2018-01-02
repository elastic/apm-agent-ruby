# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Errors < Serializer
      def build(error)
        base = {
          id: error.id,
          culprit: error.culprit,
          timestamp: micros_to_time(error.timestamp).utc.iso8601
        }

        if (exception = error.exception)
          base[:exception] = build_exception exception
        end

        base
      end

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
          unhandled: !exception.handled
        }
      end
    end
  end
end
