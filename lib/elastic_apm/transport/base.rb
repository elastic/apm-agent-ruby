# frozen_string_literal: true

require 'elastic_apm/metadata'
require 'elastic_apm/transport/connection'
require 'elastic_apm/transport/worker'
require 'elastic_apm/transport/serializers'
require 'elastic_apm/transport/filters'

module ElasticAPM
  module Transport
    # @api private
    class Base
      include Logging

      def initialize(config)
        @config = config
        @queue = SizedQueue.new(config.api_buffer_size)
        @pool = Concurrent::FixedThreadPool.new(config.pool_size)
        @workers = []

        @serializers = Serializers.new(config)
        @filters = Filters.new(config)
      end

      attr_reader :config, :queue, :workers, :filters

      def start
      end

      def stop
        stop_workers
      end

      def submit(resource)
        queue.push(resource, true)

        ensure_worker_count
      rescue ThreadError
        warn 'Queue is full (%i items), skipping…', config.api_buffer_size
        nil
      end

      def add_filter(key, callback)
        @filters.add(key, callback)
      end

      private

      def ensure_worker_count
        missing = config.pool_size - @workers.length
        return unless missing > 0

        info 'Booting %i workers', missing
        missing.times { boot_worker }
      end

      # rubocop:disable Metrics/MethodLength
      def boot_worker
        worker = Worker.new(
          config,
          queue,
          serializers: @serializers,
          filters: @filters
        )

        @workers.push worker

        @pool.post do
          worker.work_forever
          @workers.delete(worker)
        end
      end
      # rubocop:enable Metrics/MethodLength

      def stop_workers
        return unless @pool.running?

        debug 'Stopping workers'
        send_stop_messages

        debug 'Shutting down pool'
        @pool.shutdown

        return if @pool.wait_for_termination(5)

        warn "Worker pool didn't close in 5 secs, killing ..."
        @pool.kill
      end

      def send_stop_messages
        @workers.each { queue.push(Worker::StopMessage.new, true) }
      rescue ThreadError
        warn 'Cannot push stop messages to worker queue as it is full'
      end
    end
  end
end
