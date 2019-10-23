# frozen_string_literal: true

module ElasticAPM
  module Transport
    class Connection
      # @api private
      class ProxyPipe
        def initialize(enc = nil, compress: true)
          rd, wr = IO.pipe(enc)

          @read = rd
          @write = Write.new(wr, compress: compress)

          # Http.rb<4 calls rewind on the request bodies, but IO::Pipe raises
          # ~mikker
          return if HTTP::VERSION.to_i >= 4
          def rd.rewind; end
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

        def self.pipe(*args)
          pipe = new(*args)
          [pipe.read, pipe.write]
        end
      end
    end
  end
end
