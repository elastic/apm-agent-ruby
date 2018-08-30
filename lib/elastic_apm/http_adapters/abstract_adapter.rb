module ElasticAPM
  module HttpAdapters
    # @api private
    class AbstractHttpAdapter
      DISABLED = 'disabled'.freeze

      def initialize(conf)
        @config = conf
      end
    end

    # @api private
    class Response
      def initialize(response)
        @response = response
      end

      def success?
        (200..299).cover? @response.code
      end

      def code
        @response.code
      end

      def body
        @response.body
      end
    end
  end
end
