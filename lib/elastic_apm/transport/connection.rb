# frozen_string_literal: true

require 'http'

require 'elastic_apm/transport/connection/proxy_pipe'
require 'elastic_apm/transport/connection/state'

module ElasticAPM
  module Transport
    # rubocop:disable Metrics/ClassLength
    # @api private
    class Connection
      include Logging

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
        @client = build_client
        @ssl_context = build_ssl_context

        @state = State.new
      end

      attr_reader :state

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def write(str)
        return false if @config.disable_send

        return false unless connect
        append(str)

        return true unless @wr.bytes_sent >= @config.api_request_size
        flush(:api_request_size)

        true
      rescue IOError => e
        error('Connection error: %s', e.inspect)
        flush(:ioerror)
        false
      rescue Errno::EPIPE => e
        error('Connection error: %s', e.inspect)
        flush(:broken_pipe)
        false
      rescue Exception => e
        error('Connection error: %s', e.inspect)
        flush(:exception)
        false
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def connected?
        state.connected?
      end

      def flush(reason = :force)
        return unless state.connected?

        debug "Closing request from #{Thread.current.object_id}"
        @wr&.close(reason)

        @request_thread&.join(2)
      end

      def inspect
        format(
          '%s state:%s>',
          super.split.first,
          State::STATES.key(state.value)
        )
      end

      private

      def build_headers
        (
          @config.http_compression? ? GZIP_HEADERS : HEADERS
        ).dup.tap do |headers|
          if (token = @config.secret_token)
            headers['Authorization'] = "Bearer #{token}"
          end
        end
      end

      def build_client
        HTTP.headers(@headers).tap do |client|
          configure_proxy(client)
        end
      end

      def configure_proxy(client)
        return client unless @config.proxy_address && @config.proxy_port

        client.via(
          @config.proxy_address,
          @config.proxy_port,
          @config.proxy_username,
          @config.proxy_password,
          @config.proxy_headers
        )
      end

      def build_ssl_context
        return unless @config.use_ssl? && @config.server_ca_cert

        OpenSSL::SSL::SSLContext.new.tap do |context|
          context.ca_file = @config.server_ca_cert
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def connect
        return true unless state.disconnected?

        state.connecting!

        debug format('Opening new request from %s', Thread.current.object_id)
        @rd, @wr = ProxyPipe.pipe(
          on_first_read: -> { state.connected! },
          compress: @config.http_compression?
        )
        append(@metadata)

        open_post_request_in_thread
        return false unless wait_for_connection

        schedule_closing if @config.api_request_time

        true
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def open_post_request_in_thread
        @request_thread = Thread.new do
          state.connecting!

          begin
            resp = @client.post(
              @url,
              body: @rd,
              ssl_context: @ssl_context
            ).flush

            if resp&.status == 202
              debug 'APM Server responded with status 202'
            elsif resp
              error "APM Server responded with an error:\n%p", resp.body.to_s
            end
          rescue Exception => e
            error "Couldn't establish connection to APM Server:\n%p", e.inspect
            @wr&.close(:connection_error)
          ensure
            state.disconnected!
            @close_task&.cancel
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def wait_for_connection
        Timeout.timeout(5) do
          loop do
            break true if state.connected?
            break false if state.disconnected?
            sleep 0.05 if state.connecting?
          end
        end
      end

      def schedule_closing
        @close_task&.cancel
        @close_task =
          Concurrent::ScheduledTask.execute(@config.api_request_time) do
            flush(:api_request_time)
          end
      end

      def append(str)
        @wr.write(str)
        str
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
