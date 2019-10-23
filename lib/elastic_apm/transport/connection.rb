# frozen_string_literal: true

require 'elastic_apm/transport/connection/http'

module ElasticAPM
  module Transport
    # rubocop:disable Metrics/ClassLength
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
        @headers = build_headers(metadata)
        @metadata = JSON.fast_generate(metadata)
        @url = config.server_url + '/intake/v2/events'
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

      def build_headers(metadata)
        (
          @config.http_compression? ? GZIP_HEADERS : HEADERS
        ).dup.tap do |headers|
          headers['User-Agent'] = build_user_agent(metadata)

          if (token = @config.secret_token)
            headers['Authorization'] = "Bearer #{token}"
          end
        end
      end

      def build_user_agent(metadata)
        runtime = metadata.dig(:metadata, :service, :runtime)

        [
          "elastic-apm-ruby/#{VERSION}",
          HTTP::Request::USER_AGENT,
          [runtime[:name], runtime[:version]].join('/')
        ].join(' ')
      end

      def build_ssl_context # rubocop:disable Metrics/MethodLength
        return unless @config.use_ssl?

        OpenSSL::SSL::SSLContext.new.tap do |context|
          if @config.server_ca_cert
            context.ca_file = @config.server_ca_cert
          else
            context.cert_store =
              OpenSSL::X509::Store.new.tap(&:set_default_paths)
          end

          context.verify_mode =
            if @config.verify_server_cert
              OpenSSL::SSL::VERIFY_PEER
            else
              OpenSSL::SSL::VERIFY_NONE
            end
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
