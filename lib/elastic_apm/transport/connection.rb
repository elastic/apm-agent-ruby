# frozen_string_literal: true

require 'http'
require 'concurrent/scheduled_task'
require 'zlib'

require 'elastic_apm/metadata'

module ElasticAPM
  module Transport
    # @api private
    # HTTP.rb calls #rewind the body stream, which IO.pipes don't support
    class ModdedIO < IO
      def self.pipe(ext_enc = nil)
        super(ext_enc).tap do |rw|
          rw[0].define_singleton_method(:rewind) { nil }
        end
      end
    end

    # @api private
    class Connection
      HEADERS = {
        'Content-Type' => 'application/x-ndjson',
        'Transfer-Encoding' => 'chunked'
      }.freeze
      GZIP_HEADERS = HEADERS.merge(
        'Content-Encoding' => 'gzip'
      ).freeze

      def initialize(config)
        @config = config

        @client = HTTP.headers(
          @config.http_compression? ? GZIP_HEADERS : HEADERS
        )

        @url = config.server_url + '/v2/intake'
        @metadata = Metadata.build(config)
        @connected = false

        @mutex = Mutex.new
      end

      def write(str)
        connect! unless connected?
        connect! if @wr.closed?

        @wr.puts(str)
      end

      def connected?
        @mutex.synchronize { @connected }
      end

      def close!
        @mutex.synchronize { @wr.close } if connected?
        @conn_thread.join if @conn_thread
      end

      private

      def connect!
        @rd, @wr = ModdedIO.pipe

        if @config.http_compression?
          @wr.binmode
          @wr = Zlib::GzipWriter.new(@wr)
        end

        @conn_thread = boot_request_thread

        schedule_closing if @config.api_request_time

        sleep 0.01 until connected?

        write(@metadata)

        self
      end

      def boot_request_thread
        Thread.new do
          @mutex.synchronize { @connected = true }
          @client.post(@url, body: @rd).flush
          @mutex.synchronize { @connected = false }
        end
      end

      def schedule_closing
        @close_task =
          Concurrent::ScheduledTask.execute(@config.api_request_time) do
            close!
          end
      end
    end
  end
end
