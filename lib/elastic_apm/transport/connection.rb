# frozen_string_literal: true

module ElasticAPM
  module Transport
    # @api private
    class Connection
      include Logging

      # A connection holds an instance `http` of an Http::Connection.
      #
      # The HTTP::Connection itself is not thread safe.
      #
      # The connection sends write requests and close requests to `http`, and
      # has to ensure no write requests are sent after closing `http`.
      #
      # The connection schedules a separate thread to close an `http`
      # connection some time in the future. To avoid the thread interfering
      # with ongoing write requests to `http`, write and close
      # requests have to be synchronized.

      def initialize(config)
        @config = config
        @metadata = JSON.fast_generate(
          Serializers::MetadataSerializer.new(config).build(
            Metadata.new(config)
          )
        )
        @url = config.server_url + '/intake/v2/events'
        @mutex = Mutex.new
      end

      attr_reader :http

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def write(str)
        return false if @config.disable_send

        begin
          bytes_written = 0

          # The request might get closed from timertask so let's make sure we
          # hold it open until we've written.
          @mutex.synchronize do
            connect if http.nil? || http.closed?
            bytes_written = http.write(str)
          end

          flush(:api_request_size) if bytes_written >= @config.api_request_size
        rescue IOError => e
          error('Connection error: %s', e.inspect)
          flush(:ioerror)
        rescue Errno::EPIPE => e
          error('Connection error: %s', e.inspect)
          flush(:broken_pipe)
        rescue Exception => e
          error('Connection error: %s', e.inspect)
          flush(:connection_error)
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def flush(reason = :force)
        # Could happen from the timertask so we need to sync
        @mutex.synchronize do
          return if http.nil?
          http.close(reason)
        end
      end

      def inspect
        format(
          '<%s url:%s closed:%s >',
          super.split.first, url, http&.closed?
        )
      end

      private

      def connect
        schedule_closing if @config.api_request_time

        @http =
          Http.open(@config, @url).tap do |http|
            http.write(@metadata)
          end
      end
      # rubocop:enable

      def schedule_closing
        @close_task&.cancel
        @close_task =
          Concurrent::ScheduledTask.execute(@config.api_request_time) do
            flush(:timeout)
          end
      end
    end
  end
end
