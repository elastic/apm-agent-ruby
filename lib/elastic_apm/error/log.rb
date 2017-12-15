# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Log
      def initialize(message, attrs = {})
        @message = message

        attrs.each do |key, val|
          send(:"#{key}=", val)
        end
      end

      attr_accessor(
        :level,
        :logger_name,
        :message,
        :param_message,
        :stacktrace
      )
    end
  end
end
