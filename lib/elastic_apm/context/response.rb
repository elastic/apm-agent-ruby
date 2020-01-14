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
        @headers_sent = headers_sent
        @finished = finished

        self.headers = headers
      end

      attr_accessor :status_code, :headers_sent, :finished
      attr_reader :headers

      def headers=(headers)
        @headers = headers&.each_with_object({}) do |(k, v), hsh|
          hsh[k] = v.to_s
        end
      end
    end
  end
end
