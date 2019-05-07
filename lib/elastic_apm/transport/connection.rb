# frozen_string_literal: true

require 'concurrent'
require 'zlib'

require 'elastic_apm/transport/connection/http'

module ElasticAPM
  module Transport
    # @api private
    class Connection
      include Logging

      # A connection holds an instance `http` of an Http::Connection.
      #
      # The HTTP::Connection itself is not thread safe.
      #
      # The connection sends write requests and close requests to `http`, and
      # has to ensure no write requests are sent after closing `http`.
      #
      # The connection schedules a separate thread to close an `http`
      # connection some time in the future. To avoid the thread interfering
      # with ongoing write requests to `http`, write and close
      # requests have to be synchronized.

      HEADERS = {
        'Content-Type' => 'application/x-ndjson',
        'Transfer-Encoding' => 'chunked'
      }.freeze
      GZIP_HEADERS = HEADERS.merge(
        'Content-Encoding' => 'gzip'
      ).freeze

      def initialize(config, metadata)
        @config = config
        @metadata = JSON.fast_generate(metadata)
        @url = config.server_url + '/intake/v2/events'
        @headers = build_headers
        @ssl_context = build_ssl_context
        @mutex = Mutex.new
      end

      attr_reader :http

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def write(str)
        return false if @config.disable_send

        begin
          bytes_written = 0

          # The request might get closed from timertask so let's make sure we
          # hold it open until we've written.
          @mutex.synchronize do
            connect if http.nil? || http.closed?
            bytes_written = http.write(str)
          end

          flush(:api_request_size) if bytes_written >= @config.api_request_size
        rescue IOError => e
          error('Connection error: %s', e.inspect)
          flush(:ioerror)
        rescue Errno::EPIPE => e
          error('Connection error: %s', e.inspect)
          flush(:broken_pipe)
        rescue Exception => e
          error('Connection error: %s', e.inspect)
          flush(:connection_error)
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def flush(reason = :force)
        # Could happen from the timertask so we need to sync
        @mutex.synchronize do
          return if http.nil?
          http.close(reason)
        end
      end

      def inspect
        format(
          '@%s http connection closed? :%s>',
          super.split.first,
          http.closed?
        )
      end

      private

      def connect
        schedule_closing if @config.api_request_time

        @http =
          Http.open(
            @config, @url,
            headers: @headers,
            ssl_context: @ssl_context
          ).tap { |http| http.write(@metadata) }
      end
      # rubocop:enable

      def schedule_closing
        @close_task&.cancel
        @close_task =
          Concurrent::ScheduledTask.execute(@config.api_request_time) do
            flush(:timeout)
          end
      end

      def build_headers
        (
          @config.http_compression? ? GZIP_HEADERS : HEADERS
        ).dup.tap do |headers|
          if (token = @config.secret_token)
            headers['Authorization'] = "Bearer #{token}"
          end
        end
      end

      def build_ssl_context
        return unless @config.use_ssl? && @config.server_ca_cert

        OpenSSL::SSL::SSLContext.new.tap do |context|
          context.ca_file = @config.server_ca_cert
        end
      end
    end
  end
end
