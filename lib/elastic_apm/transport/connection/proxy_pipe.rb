# frozen_string_literal: true

require 'concurrent'
require 'zlib'

module ElasticAPM
  module Transport
    class Connection
      # @api private
      class ProxyPipe
        def initialize(enc = nil, on_first_read: nil, compress: true)
          rd, wr = IO.pipe(enc)

          @read = Read.new(rd, on_first_read)
          @write = Write.new(wr, compress: compress)
        end

        attr_reader :read, :write

        # @api private
        class Write
          include Logging

          def initialize(io, compress: true)
            @io = io
            @compress = compress
            @bytes_sent = Concurrent::AtomicFixnum.new(0)
            @config = ElasticAPM.agent&.config # this is silly, fix Logging

            return unless compress
            enable_compression!
          end

          attr_reader :io

          def enable_compression!
            io.binmode
            @io = Zlib::GzipWriter.new(io)
          end

          def close(reason = nil)
            debug("Closing writer with reason #{reason}")
            io.close
          end

          def closed?
            io.closed?
          end

          def write(str)
            io.puts(str).tap do
              @bytes_sent.update do |curr|
                @compress ? io.tell : curr + str.bytesize
              end
            end
          end

          def bytes_sent
            @bytes_sent.value
          end
        end

        # @api private
        class Read
          def initialize(io, callback = nil)
            @io = io
            @callback = callback
          end

          attr_reader :io

          def read(*args)
            if @callback
              @callback.call
              @callback = nil
            end

            io.read(*args)
          end

          def readpartial(*args)
            if @callback
              @callback.call
              @callback = nil
            end

            io.readpartial(*args)
          end

          # not supported, but http.rb calls it
          def rewind
          end

          def method_missing(name, *args, &block)
            return @io.send(name, *args, &block) if @io.respond_to?(name)
            super
          end

          private

          def respond_to_missing?(name, include_all)
            @io.respond_to?(name) || super
          end
        end

        def self.pipe(*args)
          pipe = new(*args)
          [pipe.read, pipe.write]
        end
      end
    end
  end
end
