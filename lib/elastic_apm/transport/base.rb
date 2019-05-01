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
        @workers = Concurrent::Hash.new
      end

      def start
        debug 'Starting Transport'
        boot_worker
      end

      def stop
        debug 'Stopping Transport'
        @stopped.try_lock
        send_stop_message

        @workers.each do |_pid, t|
          t.join(5)
        end
        @workers.clear
      end

      def submit(resource)
        if stopped?
          warn 'Transport stopping, new events not accepted…'
          return false
        end

        boot_worker
        queue.push(resource, true)
      rescue ThreadError
        warn 'Queue is full (%i items), skipping…', config.api_buffer_size
        nil
      rescue Exception => e
        error 'Failed adding to the transport queue: %p', e.inspect
        nil
      end

      def add_filter(key, callback)
        @filters.add(key, callback)
      end

      attr_reader :queue

      private

      attr_reader :config, :filters, :pool, :workers, :supervisor
      def boot_worker
        return if @workers[Process.pid] && @workers[Process.pid].alive?
        debug 'Booting worker...'

        @workers[Process.pid] = Thread.new do
          Worker.new(
            config,
            queue,
            serializers: @serializers,
            filters: @filters
          ).work_forever
        end
      end

      def send_stop_message
        queue.push(Worker::StopMessage.new, true)
      rescue ThreadError
        warn 'Cannot push stop messages to worker queue as it is full'
      end

      def stopped?
        @stopped.locked?
      end
    end
  end
end
