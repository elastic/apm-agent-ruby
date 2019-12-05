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
        @db = db && Db.new(db)
        @http = http && Http.new(http)
        @destination = destination && Destination.new(destination)
        @labels = labels
      end

      attr_reader(
        :db,
        :destination,
        :http,
        :labels,
        :sync
      )

      def self.from_uri(uri)
      end
    end
  end
end

require 'elastic_apm/span/context/db'
require 'elastic_apm/span/context/http'
require 'elastic_apm/span/context/destination'
