# frozen_string_literal: true

module ElasticAPM
  class Span
    # @api private
    class Context
      include NaivelyHashable

      def initialize(args)
        args.each do |key, val|
          send(:"#{key}=", val)
        end
      end

      attr_accessor :instance, :statement, :type, :user
    end
  end
end
