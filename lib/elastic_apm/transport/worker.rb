# frozen_string_literal: true

module ElasticAPM
  module Transport
    # @api private
    class Worker
      include Logging

      # @api private
      class StopMessage; end

      # @api private
      class FlushMessage; end

      def initialize(
        config,
        queue,
        serializers:,
        filters:,
        conn_adapter: Connection
      )
        @config = config
        @queue = queue

        @stopping = false

        @serializers = serializers
        @filters = filters

        metadata = serializers.serialize(Metadata.new(config))
        @connection = conn_adapter.new(config, metadata)
      end

      attr_reader :queue, :filters, :name, :connection, :serializers

      def stop
        @stopping = true
      end

      def stopping?
        @stopping
      end

      # rubocop:disable Metrics/MethodLength
      def work_forever
        while (msg = queue.pop)
          case msg
          when StopMessage
            stop
          else
            process msg
          end

          next unless stopping?

          debug 'Stopping worker -- %s', self
          @connection.flush
          break
        end
      rescue Exception => e
        warn 'Worker died with exception: %s', e.inspect
        debug e.backtrace.join("\n")
      end
      # rubocop:enable Metrics/MethodLength

      def process(resource)
        return unless (json = serialize_and_filter(resource))
        @connection.write(json)
      rescue Zlib::GzipFile::Error => e
        warn 'Unexpectedly closed GZip stream encountered. '\
          'Dropping event and flushing connection... '
        error e.inspect
        @connection.flush
      end

      private

      def serialize_and_filter(resource)
        serialized = serializers.serialize(resource)
        @filters.apply!(serialized)
        JSON.fast_generate(serialized)
      rescue Exception => e
        error format('Failed converting event to JSON: %s', resource.inspect)
        error e.inspect
        error (format('Dump:\n%s', serialized.inspect))
        # debug('Backtrace:') { e.backtrace.join("\n") }
        nil
      end
    end
  end
end
