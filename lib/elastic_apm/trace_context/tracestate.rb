# frozen_string_literal: true

module ElasticAPM
  class TraceContext
    # @api private
    class Tracestate
      def initialize(values = [])
        @values = values
      end

      attr_accessor :values

      def self.parse(header)
        # HTTP allows multiple headers with the same name, eg. multiple
        # Set-Cookie headers per response.
        # Rack handles this by joining the headers under the same key, separated
        # by newlines, see https://www.rubydoc.info/github/rack/rack/file/SPEC
        new(String(header).split("\n"))
      end

      def to_header
        values.join(',')
      end
    end
  end
end
