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

        @connection = conn_adapter.new(config)
        @serializers = serializers
        @filters = filters
      end

      attr_reader :queue, :filters, :name, :connection, :serializers

      def stop
        @stopping = true
      end

      def stopping?
        @stopping
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def work_forever
        while (msg = queue.pop)
          info '<' * (queue.length + 1)
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
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      private

      def process(resource)
        serialized = serializers.serialize(resource)
        @filters.apply!(serialized)
        @connection.write(serialized.to_json)
      end
    end
  end
end
