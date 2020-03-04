# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      # @api private
      class Db
        def initialize(
          instance: nil,
          statement: nil,
          type: nil,
          user: nil,
          rows_affected: nil
        )
          @instance = instance
          @statement = statement
          @type = type
          @user = user
          @rows_affected = rows_affected
        end

        attr_accessor :instance, :statement, :type, :user, :rows_affected
      end
    end
  end
end
