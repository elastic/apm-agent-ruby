# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      # @api private
      class Db
        def initialize(instance: nil, statement: nil, type: nil, user: nil)
          @instance = instance
          @statement = statement
          @type = type
          @user = user
        end

        attr_accessor :instance, :statement, :type, :user
      end
    end
  end
end
