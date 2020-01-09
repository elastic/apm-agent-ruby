# frozen_string_literal: true

module ElasticAPM
  module Transport
    # @api private
    class Headers
      HEADERS = {
        'Content-Type' => 'application/x-ndjson',
        'Transfer-Encoding' => 'chunked'
      }.freeze
      GZIP_HEADERS = HEADERS.merge(
        'Content-Encoding' => 'gzip'
      ).freeze

      def initialize(config, initial: {})
        @config = config
        @hash = build!(initial)
      end

      attr_accessor :hash

      def [](key)
        @hash[key]
      end

      def []=(key, value)
        @hash[key] = value
      end

      def merge(other)
        self.class.new(@config, initial: @hash.merge(other))
      end

      def merge!(other)
        @hash.merge!(other)
        self
      end

      def to_h
        @hash
      end

      def chunked
        merge(
          @config.http_compression? ? GZIP_HEADERS : HEADERS
        )
      end

      private

      def build!(headers)
        headers[:'User-Agent'] = UserAgent.new(@config).to_s

        if (token = @config.secret_token)
          headers[:Authorization] = "Bearer #{token}"
        end

        if (api_key = @config.api_key)
          headers[:Authorization] = "ApiKey #{api_key}"
        end

        headers
      end
    end
  end
end
