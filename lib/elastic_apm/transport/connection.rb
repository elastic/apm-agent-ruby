# frozen_string_literal: true

require 'http'
require 'concurrent'
require 'zlib'

module ElasticAPM
  module Transport
    # @api private
    class Connection # rubocop:disable Metrics/ClassLength
      include Logging

      class FailedToConnectError < InternalError; end

      # @api private
      # HTTP.rb calls #rewind the body stream which IO.pipes don't support
      class ModdedIO < IO
        def self.pipe(ext_enc = nil)
          super(ext_enc).tap do |rw|
            rw[0].define_singleton_method(:rewind) { nil }
          end
        end
      end

      HEADERS = {
        'Content-Type' => 'application/x-ndjson',
        'Transfer-Encoding' => 'chunked'
      }.freeze
      GZIP_HEADERS = HEADERS.merge('Content-Encoding' => 'gzip').freeze

      # rubocop:disable Metrics/MethodLength
      def initialize(config, metadata)
        @config = config
        @metadata = metadata.to_json

        @url = config.server_url + '/intake/v2/events'

        headers =
          (@config.http_compression? ? GZIP_HEADERS : HEADERS).dup

        if (token = config.secret_token)
          headers['Authorization'] = "Bearer #{token}"
        end

        @client = HTTP.headers(headers).persistent(@url)

        configure_proxy
        configure_ssl

        @mutex = Mutex.new
      end
      # rubocop:enable Metrics/MethodLength

      def configure_proxy
        unless @config.proxy_address && @config.proxy_port
          return
        end

        @client = @client.via(
          @config.proxy_address,
          @config.proxy_port,
          @config.proxy_username,
          @config.proxy_password,
          @config.proxy_headers
        )
      end

      def configure_ssl
        return unless @config.use_ssl? && @config.server_ca_cert

        @ssl_context = OpenSSL::SSL::SSLContext.new.tap do |context|
          context.ca_file = @config.server_ca_cert
        end
      end

      def write(str)
        return if @config.disable_send

        connect_unless_connected

        @mutex.synchronize { append(str) }

        return unless @bytes_sent >= @config.api_request_size

        flush
      rescue FailedToConnectError => e
        error "Couldn't establish connection to APM Server:\n%p", e
        flush

        nil
      end

      def connected?
        @mutex.synchronize { @connected }
      end

      def flush
        @mutex.synchronize do
          return unless @connected

          debug 'Closing request'
          @wr.close
          @conn_thread.join 5 if @conn_thread
        end
      end

      private

      # rubocop:disable Metrics/MethodLength
      def connect_unless_connected
        @mutex.synchronize do
          return true if @connected

          debug 'Opening new request'

          reset!

          @rd, @wr = ModdedIO.pipe

          enable_compression! if @config.http_compression?

          perform_request_in_thread
          wait_for_connection

          schedule_closing if @config.api_request_time

          append(@metadata)

          true
        end
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def perform_request_in_thread
        @conn_thread = Thread.new do
          begin
            @connected = true

            resp = @client.post(
              @url,
              body: @rd,
              ssl_context: @ssl_context
            ).flush
          rescue Exception => e
            @connection_error = e
          ensure
            @connected = false
          end

          if resp&.status == 202
            debug 'APM Server responded with status 202'
          elsif resp
            error "APM Server responded with an error:\n%p", resp.body.to_s
          end

          resp
        end
      end
      # rubocop:enable Metrics/MethodLength

      def append(str)
        bytes =
          if @config.http_compression
            @bytes_sent = @wr.tell
          else
            @bytes_sent += str.bytesize
          end

        debug 'Bytes sent during this request: %d', bytes

        @wr.puts(str)
      end

      def schedule_closing
        @close_task =
          Concurrent::ScheduledTask.execute(@config.api_request_time) do
            flush
          end
      end

      def enable_compression!
        @wr.binmode
        @wr = Zlib::GzipWriter.new(@wr)
      end

      def reset!
        @bytes_sent = 0
        @connected = false
        @connection_error = nil
        @close_task = nil
      end

      def wait_for_connection
        until @connected
          if (exception = @connection_error)
            @wr&.close
            raise FailedToConnectError, exception
          end

          sleep 0.01
        end
      end
    end
  end
end
