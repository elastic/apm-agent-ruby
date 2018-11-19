# frozen_string_literal: true

module ElasticAPM
  class Context
    # @api private
    class Response
      def initialize(
        status_code,
        headers: {},
        headers_sent: true,
        finished: true
      )
        @status_code = status_code
        @headers = headers
        @headers_sent = headers_sent
        @finished = finished
      end

      attr_accessor :status_code, :headers, :headers_sent, :finished
    end
  end
end
