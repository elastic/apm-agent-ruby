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
        serializer = Serializers::MetadataSerializer.new(config)
        metadata = serializer.build(Metadata.new(config))
        runtime = metadata.dig(:metadata, :service, :runtime)

        [
          "elastic-apm-ruby/#{VERSION}",
          HTTP::Request::USER_AGENT,
          [runtime[:name], runtime[:version]].join('/')
        ].join(' ')
      end
    end
  end
end
