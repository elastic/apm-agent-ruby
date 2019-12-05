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

      attr_accessor :sync, :db, :http, :labels
      attr_reader :destination

      def self.from_uri(uri)
        new(
          http: { url: uri.to_s },
          destination: {
            name: uri.to_s,
            resource: "#{uri.host}:#{uri.port}",
            type: 'external'
          }
        )
      end
    end
  end
end

require 'elastic_apm/span/context/db'
require 'elastic_apm/span/context/http'
require 'elastic_apm/span/context/destination'
