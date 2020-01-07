# frozen_string_literal: true

module ElasticAPM
  class Span
    # @api private
    class Context
      def initialize(
        db: nil,
        destination: nil,
        http: nil,
        labels: {},
        sync: nil
      )
        @sync = sync
        @db = db && Db.new(**db)
        @http = http && Http.new(**http)
        @destination =
          case destination
          when Destination then destination
          when Hash then Destination.new(**destination)
          end
        @labels = labels
      end

      attr_reader(
        :db,
        :destination,
        :http,
        :labels,
        :sync
      )
    end
  end
end

require 'elastic_apm/span/context/db'
require 'elastic_apm/span/context/http'
require 'elastic_apm/span/context/destination'
