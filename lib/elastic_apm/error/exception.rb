# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Exception
      def initialize(message, type = nil)
        @message = message
        @type = type
      end

      attr_accessor(
        :message,
        :type,
        :module,
        :code,
        :attributes,
        :stacktrace,
        :uncaught
      )
    end
  end
end
