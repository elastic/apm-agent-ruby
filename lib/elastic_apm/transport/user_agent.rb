# frozen_string_literal: true

module ElasticAPM
  module Transport
    # @api private
    class UserAgent
      def initialize
        @built = build
      end

      def to_s
        @built
      end

      private

      def build
        metadata = Metadata.new

        [
          "elastic-apm-ruby/#{VERSION}",
          HTTP::Request::USER_AGENT,
          [
            metadata.service.runtime.name,
            metadata.service.runtime.version
          ].join('/')
        ].join(' ')
      end
    end
  end
end
