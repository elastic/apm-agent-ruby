# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Exception
      MOD_SPLIT = '::'

      def initialize(attrs = nil)
        return unless attrs

        attrs.each do |key, val|
          send(:"#{key}=", val)
        end
      end

      def self.from_exception(exception, **attrs)
        new({
          message: exception.message.to_s,
          type: exception.class.to_s,
          module: format_module(exception)
        }.merge(attrs))
      end

      attr_accessor :attributes
      attr_accessor :code
      attr_accessor :handled
      attr_accessor :message
      attr_accessor :module
      attr_accessor :stacktrace
      attr_accessor :type

      class << self
        private

        def format_module(exception)
          exception.class.to_s.split(MOD_SPLIT)[0...-1].join(MOD_SPLIT)
        end
      end
    end
  end
end
