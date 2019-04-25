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

        @serializers = Serializers.new(config)
        @filters = Filters.new(config)

        @stopped = Mutex.new
        @pool = Concurrent::FixedThreadPool.new(config.pool_size)
        @workers = Concurrent::Array.new
        @supervisor = init_supervisor
      end

      def start
        debug 'Starting Transport'
        ensure_worker_count
        supervisor.execute
      end

      def stop
        debug 'Stopping Transport'
        @stopped.try_lock
        supervisor.shutdown
        stop_workers
      end

      def submit(resource)
        if stopped?
          warn 'Transport stopping, new events not accepted…'
          return false
        end
        queue.push(resource, true)
      rescue ThreadError
        warn 'Queue is full (%i items), skipping…', config.api_buffer_size
        nil
      end

      def add_filter(key, callback)
        @filters.add(key, callback)
      end

      attr_reader :queue

      private

      attr_reader :config, :filters, :pool, :workers, :supervisor

      def missing_worker
        config.pool_size - workers.length
      end

      def ensure_worker_count
        missing_worker.times { boot_worker }
      end

      # rubocop:disable Metrics/MethodLength
      def boot_worker
        return if missing_worker <= 0

        debug 'Booting worker...'
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
        config.pool_size.times { queue.push(Worker::StopMessage.new, true) }
      rescue ThreadError
        warn 'Cannot push stop messages to worker queue as it is full'
      end

      def stopped?
        @stopped.locked?
      end

      def init_supervisor
        @supervisor = Concurrent::TimerTask.new(execution_interval: 2,
                                                timeout_interval: 1) do
          ensure_worker_count unless stopped?
        end
      end
    end
  end
end
