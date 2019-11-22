# frozen_string_literal: true

require 'elastic_apm/metadata'
require 'elastic_apm/transport/user_agent'
require 'elastic_apm/transport/headers'
require 'elastic_apm/transport/connection'
require 'elastic_apm/transport/worker'
require 'elastic_apm/transport/serializers'
require 'elastic_apm/transport/filters'
require 'elastic_apm/transport/connection/http'

require 'elastic_apm/util/throttle'

module ElasticAPM
  module Transport
    # @api private
    class Base
      include Logging

      WATCHER_EXECUTION_INTERVAL = 5
      WATCHER_TIMEOUT_INTERVAL = 4
      WORKER_JOIN_TIMEOUT = 5

      def initialize(config)
        @config = config
        @queue = SizedQueue.new(config.api_buffer_size)

        @serializers = Serializers.new(config)
        @filters = Filters.new(config)

        @stopped = Concurrent::AtomicBoolean.new
        @workers = Array.new(config.pool_size)

        @watcher_mutex = Mutex.new
        @worker_mutex = Mutex.new
      end

      attr_reader :config, :queue, :filters, :workers, :watcher, :stopped

      def start
        debug '%s: Starting Transport', pid_str

        ensure_watcher_running
        ensure_worker_count

        @stopped.make_false unless @stopped.false?
      end

      def stop
        debug '%s: Stopping Transport', pid_str

        @stopped.make_true

        stop_watcher
        stop_workers
      end

      def submit(resource)
        if @stopped.true?
          warn '%s: Transport stopping, no new events accepted', pid_str
          debug 'Dropping: %s', resource.inspect
          return false
        end

        ensure_watcher_running
        queue.push(resource, true)

        true
      rescue ThreadError
        throttled_queue_full_warning
        nil
      rescue Exception => e
        error '%s: Failed adding to the transport queue: %p', pid_str, e.inspect
        nil
      end

      def add_filter(key, callback)
        @filters.add(key, callback)
      end

      private

      def pid_str
        format('[PID:%s]', Process.pid)
      end

      def ensure_watcher_running
        # pid has changed == we've forked
        return if @pid == Process.pid

        @watcher_mutex.synchronize do
          return if @pid == Process.pid
          @pid = Process.pid

          @watcher = Concurrent::TimerTask.execute(
            execution_interval: WATCHER_EXECUTION_INTERVAL,
            timeout_interval: WATCHER_TIMEOUT_INTERVAL
          ) { ensure_worker_count }
        end
      end

      def ensure_worker_count
        @worker_mutex.synchronize do
          return if all_workers_alive?
          return if stopped.true?

          @workers.map! do |thread|
            next thread if thread&.alive?

            boot_worker
          end
        end
      end

      def all_workers_alive?
        !!workers.all? { |t| t&.alive? }
      end

      def boot_worker
        debug '%s: Booting worker...', pid_str

        Thread.new do
          Worker.new(
            config, queue,
            serializers: @serializers,
            filters: @filters
          ).work_forever
        end
      end

      def stop_workers
        debug '%s: Stopping workers', pid_str

        send_stop_messages

        @worker_mutex.synchronize do
          workers.each do |thread|
            next if thread.nil?
            next if thread.join(WORKER_JOIN_TIMEOUT)

            debug(
              '%s: Worker did not stop in %ds, killing...',
              pid_str, WORKER_JOIN_TIMEOUT
            )
            thread.kill
          end

          @workers.clear
        end
      end

      def send_stop_messages
        config.pool_size.times { queue.push(Worker::StopMessage.new, true) }
      rescue ThreadError
        warn 'Cannot push stop messages to worker queue as it is full'
      end

      def stop_watcher
        @watcher_mutex.synchronize do
          return if watcher.nil? || @pid != Process.pid
          watcher.shutdown
        end
      end

      def throttled_queue_full_warning
        (@queue_full_log ||= Util::Throttle.new(5) do
          warn(
            '%s: Queue is full (%i items), skipping…',
            pid_str, config.api_buffer_size
          )
        end).call
      end
    end
  end
end
