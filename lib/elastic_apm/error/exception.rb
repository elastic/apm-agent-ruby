# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Exception
      MOD_SPLIT = '::'

      def initialize(original_exception, **attrs)
        @message =
          "#{original_exception.class}: #{original_exception.message}"
        @type = original_exception.class.to_s
        @module = format_module original_exception

        attrs.each do |key, val|
          send(:"#{key}=", val)
        end
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

      private

      def format_module(exception)
        exception.class.to_s.split(MOD_SPLIT)[0...-1].join(MOD_SPLIT)
      end
    end
  end
end
