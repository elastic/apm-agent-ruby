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

        @serializers = serializers
        @filters = filters

        metadata = serializers.serialize(Metadata.new(config))
        @connection = conn_adapter.new(config, metadata)
      end

      attr_reader :queue, :filters, :name, :connection, :serializers

      # rubocop:disable Metrics/MethodLength
      def work_forever
        while (msg = queue.pop)
          case msg
          when StopMessage
            debug 'Stopping worker -- %s', self
            connection.flush(:halt)
            break
          else
            process msg
          end
        end
      rescue Exception => e
        warn 'Worker died with exception: %s', e.inspect
        debug e.backtrace.join("\n")
      end
      # rubocop:enable Metrics/MethodLength

      def process(resource)
        return unless (json = serialize_and_filter(resource))
        connection.write(json)
      end

      private

      def serialize_and_filter(resource)
        serialized = serializers.serialize(resource)

        # if a filter returns nil, it means skip the event
        return nil if @filters.apply!(serialized) == Filters::SKIP

        JSON.fast_generate(serialized)
      rescue Exception
        error format('Failed converting event to JSON: %s', resource.inspect)
        error serialized.inspect
        nil
      end
    end
  end
end
