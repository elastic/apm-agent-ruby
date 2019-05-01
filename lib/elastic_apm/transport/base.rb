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

        @stopped = Concurrent::AtomicBoolean.new
        @mutex = Mutex.new
      end

      def start
        debug "#{pid_str}: Starting Transport"

        start_watcher
      end

      def stop
        debug "#{pid_str}: Stopping Transport"

        @stopped.make_true
        stop_watcher
        stop_workers
      end

      # rubocop:disable Metrics/MethodLength, Metrics/LineLength
      def submit(resource)
        if @stopped.true?
          warn "#{pid_str}: Transport stopping, no new events accepted"
          return false
        end

        start_watcher
        queue.push(resource, true)
      rescue ThreadError
        warn "#{pid_str}: Queue is full (%i items), skipping…", config.api_buffer_size
        nil
      rescue Exception => e
        error "#{pid_str}: Failed adding to the transport queue: %p", e.inspect
        nil
      end
      # rubocop:enable Metrics/MethodLength, Metrics/LineLength

      def add_filter(key, callback)
        @filters.add(key, callback)
      end

      attr_reader :queue

      private

      attr_reader :config, :filters, :pool, :workers, :watcher, :stopped

      def watch_workers
        return if working?

        @workers ||= Array.new(config.pool_size)
        @mutex.synchronize do
          return if stopped.true?
          @workers.map! do |t|
            next t if t&.alive?
            boot_worker
          end
        end
      end

      def boot_worker
        debug "#{pid_str}: Booting worker..."

        Thread.new do
          Worker
            .new(config, queue,
              serializers: @serializers,
              filters: @filters)
            .work_forever
        end
      end

      def working?
        workers&.all? { |t| t&.alive? }
      end

      def stop_workers
        debug "#{pid_str}: Stopping workers"

        send_stop_messages
        @mutex.synchronize do
          workers&.each do |t|
            next if t.join(5)
            debug "#{pid_str}: Worker did not stop in time"
            t.kill
          end
        end
        @workers.clear
      end

      def send_stop_messages
        config.pool_size.times { queue.push(Worker::StopMessage.new, true) }
      rescue ThreadError
        warn 'Cannot push stop messages to worker queue as it is full'
      end

      def start_watcher
        return if @pid == Process.pid
        @pid = Process.pid

        # run once immediately, then schedule worker to run every interval
        watch_workers
        t = Concurrent::TimerTask.new(execution_interval: 5,
                                      timeout_interval: 4) do
          watch_workers
        end
        t.execute
        @watcher = t
      end

      def stop_watcher
        return if watcher.nil? || @pid != Process.pid
        watcher.shutdown
      end

      def pid_str
        "[PID]#{Process.pid}"
      end
    end
  end
end
