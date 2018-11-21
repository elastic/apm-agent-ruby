# frozen_string_literal: true

module ElasticAPM
  class Span
    # @api private
    class Context
      def initialize(db: nil, http: nil)
        @db = db && Db.new(db)
        @http = http && Http.new(http)
      end

      attr_accessor :sync, :db, :http

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

      # @api private
      class Http
        def initialize(url: nil, status_code: nil, method: nil)
          @url = url
          @status_code = status_code
          @method = method
        end

        attr_accessor :url, :status_code, :method
      end
    end
  end
end
