# frozen_string_literal: true

require 'http'
require 'concurrent/scheduled_task'
require 'zlib'

require 'elastic_apm/metadata'

module ElasticAPM
  module Transport
    # @api private
    class Connection
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
        @connected = false

        @mutex = Mutex.new
      end

      def write(str)
        connect! unless connected?
        # connect! if @wr.closed?

        if @config.http_compression
          @bytes_sent = @wr.tell
        else
          @bytes_sent += str.bytesize
        end

        @wr.puts(str)

        return unless @bytes_sent >= @config.api_request_size

        close!
      end

      def connected?
        @mutex.synchronize { @connected }
      end

      def close!
        @mutex.synchronize { @wr.close } if connected?
        @conn_thread.join if @conn_thread
      end

      private

      # rubocop:disable Metrics/MethodLength
      def connect!
        @rd, @wr = ModdedIO.pipe
        @bytes_sent = 0

        if @config.http_compression?
          @wr.binmode
          @wr = Zlib::GzipWriter.new(@wr)
        end

        @conn_thread = perform_request_in_thread

        schedule_closing if @config.api_request_time

        sleep 0.01 until connected?

        write(@metadata)

        self
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def perform_request_in_thread
        Thread.new do
          begin
            @mutex.synchronize { @connected = true }
            resp = @client.post(@url, body: @rd).flush
          ensure
            @mutex.synchronize { @connected = false }
          end

          unless resp&.status == 202
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
    end
  end
end
