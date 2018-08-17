# frozen_string_literal: true

require 'concurrent/scheduled_task'

module ElasticAPM
  module Transport
    # @api private
    # HTTP.rb calls #rewind the body stream, which IO.pipes don't support
    class ModdedIO < IO
      def self.pipe(*args)
        super.tap do |rw|
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

      def initialize(url, max_request_time: nil, max_request_size: nil)
        @url = url
        @client = HTTP.headers(HEADERS)

        @mutex = Mutex.new

        @max_request_time = max_request_time
        @max_request_size = max_request_size

        @connected = false
      end

      def close!
        @mutex.synchronize { @wr.close } if connected?

        @conn_thread.join if @conn_thread
      end

      def write(str)
        connect! unless connected?
        connect! if @wr.closed?

        @wr.puts(str)
      end

      def connected?
        @mutex.synchronize { @connected }
      end

      private

      def connect!
        @rd, @wr = ModdedIO.pipe

        @conn_thread = Thread.new do
          @mutex.synchronize { @connected = true }
          @client.post(@url, body: @rd).flush
          @mutex.synchronize { @connected = false }
        end

        schedule_closing if @max_request_time

        sleep 0.01 until connected?
      end

      def schedule_closing
        @close_task = Concurrent::ScheduledTask.execute(@max_request_time) do
          close! if connected?
        end.execute
      end
    end
  end
end
