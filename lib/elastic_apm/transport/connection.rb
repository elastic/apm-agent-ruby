# frozen_string_literal: true

module ElasticAPM
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

    def initialize
      @mutex = Mutex.new
      @client = HTTP.headers(HEADERS)
      @connected = false
    end

    def close!
      @wr.close
      @conn_thread.join
    end

    def write(str)
      connect! unless connected?

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
        @client.post('http://localhost:4321/v2/intake', body: @rd).flush
        @mutex.synchronize { @connected = false }
      end

      sleep 0.1 until connected? # TODO: timeout
    end
  end
end
