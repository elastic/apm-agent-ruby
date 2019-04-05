# frozen_string_literal: true

module ElasticAPM
  module Transport
    class Connection
      # @api private
      class ProxyPipe
        def initialize(enc = nil, on_first_read: nil)
          rd, wr = IO.pipe(enc)

          @read = Read.new(rd, on_first_read)
          @write = Write.new(wr)
        end

        attr_reader :read, :write

        # @api private
        class Write
          def initialize(io)
            @io = io
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

        # @api private
        class Read
          def initialize(io, callback = nil)
            @io = io
            @callback = callback
          end

          def readpartial(*args)
            if @callback
              @callback.call
              @callback = nil
            end

            @io.send(:readpartial, *args)
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

        def self.pipe(enc = nil, on_first_read: nil)
          pipe = new(enc, on_first_read: on_first_read)
          [pipe.read, pipe.write]
        end
      end
    end
  end
end
