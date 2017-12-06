# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Exception
      def initialize(message, type = nil, handled: false)
        @message = message
        @type = type
        @handled = handled
      end

      attr_accessor(
        :attributes,
        :code,
        :handled,
        :message,
        :module,
        :stacktrace,
        :type
      )
    end
  end
end
