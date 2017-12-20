# frozen_string_literal: true

module ElasticAPM
  class Span
    # @api private
    class Context
      def initialize(**args)
        args.each do |key, val|
          send(:"#{key}=", val)
        end
      end

      attr_accessor :instance, :statement, :type, :user

      def to_h
        { instance: instance, statement: statement, type: type, user: user }
      end
    end
  end
end
