# frozen_string_literal: true

require 'http'
require 'concurrent/scheduled_task'
require 'zlib'

require 'elastic_apm/metadata'

module ElasticAPM
  module Transport
    # @api private
    class Connection
      class FailedToConnectError < InternalError; end

      include Log

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
      GZIP_HEADERS = HEADERS.merge(
        'Content-Encoding' => 'gzip'
      ).freeze

      def initialize(config)
        @config = config

        @url = config.server_url + '/v2/intake'

        @client = HTTP.headers(
          @config.http_compression? ? GZIP_HEADERS : HEADERS
        ).persistent(@url)

        @metadata = Metadata.build(config)

        @mutex = Mutex.new
      end

      # rubocop:disable Metrics/MethodLength
      def write(str)
        connect! unless connected?

        if @config.http_compression
          @bytes_sent = @wr.tell
        else
          @bytes_sent += str.bytesize
        end

        @wr.puts(str)

        return unless @bytes_sent >= @config.api_request_size

        close!
      rescue FailedToConnectError => e
        error format("Couldn't establish connection to APM Server:\n%s", e)

        nil
      end
      # rubocop:enable Metrics/MethodLength

      def connected?
        @mutex.synchronize { @connected }
      end

      def close!
        @mutex.synchronize { @wr.close } if connected?
        @conn_thread.join 0.1 if @conn_thread
      end

      private

      def connect!
        reset!

        enable_compression if @config.http_compression?
        perform_request_in_thread
        wait_for_connection
        schedule_closing if @config.api_request_time

        write(@metadata)

        true
      end

      # rubocop:disable Metrics/MethodLength
      def perform_request_in_thread
        @conn_thread = Thread.new do
          begin
            @mutex.synchronize { @connected = true }
            resp = @client.post(@url, body: @rd).flush
          rescue Exception => e
            @connection_error = e
          ensure
            @mutex.synchronize { @connected = false }
          end

          if resp && resp.status != 202
            error format("APM Server reponded with an error:\n%s", resp.body)
          end

          resp
        end
      end
      # rubocop:enable Metrics/MethodLength

      def schedule_closing
        @close_task =
          Concurrent::ScheduledTask.execute(@config.api_request_time) do
            close!
          end
      end

      def enable_compression
        @wr.binmode
        @wr = Zlib::GzipWriter.new(@wr)
      end

      def reset!
        @bytes_sent = 0
        @connected = false
        @connection_error = nil
        @close_task = nil
        @rd, @wr = ModdedIO.pipe
      end

      def wait_for_connection
        until connected?
          if (exception = @mutex.synchronize { @connection_error })
            @wr&.close
            raise FailedToConnectError, exception
          end

          sleep 0.01
        end
      end
    end
  end
end
