# frozen_string_literal: true

module ElasticAPM
  module Serializers
    # @api private
    class Errors < Serializer
      # rubocop:disable Metrics/MethodLength
      def build(errors)
        {
          errors: errors.map do |error|
            base = {
              id: SecureRandom.uuid,
              culprit: error.culprit,
              timestamp: micros_to_time(error.timestamp).utc.iso8601
            }

            if (exception = error.exception)
              base[:exception] = build_exception exception
            end

            base
          end
        }
      end
      # rubocop:enable Metrics/MethodLength

      private

      def build_exception(exception)
        {
          message: exception.message,
          type: exception.type,
          module: exception.module,
          code: exception.code,
          attributes: exception.attributes,
          stacktrace: exception.stacktrace.to_h,
          uncaught: exception.uncaught
        }
      end
    end
  end
end
