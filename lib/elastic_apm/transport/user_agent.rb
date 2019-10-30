# frozen_string_literal: true

module ElasticAPM
  module Transport
    # @api private
    class UserAgent
      def initialize(config)
        @built = build(config)
      end

      def to_s
        @built
      end

      private

      def build(config)
        metadata = Metadata.new(config)

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
