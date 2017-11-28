# frozen_string_literal: true

require 'elastic_apm/error_builder'
require 'elastic_apm/error'
require 'elastic_apm/http'
require 'elastic_apm/injectors'
require 'elastic_apm/serializers'
require 'elastic_apm/worker'

module ElasticAPM
  # @api private
  class Agent
    include Log

    LOCK = Mutex.new

    # life cycle

    def self.instance # rubocop:disable Style/TrivialAccessors
      @instance
    end

    def self.start(config)
      return @instance if @instance

      LOCK.synchronize do
        return @instance if @instance
        @instance = new(config).start
      end
    end

    def self.stop
      LOCK.synchronize do
        return unless @instance

        @instance.stop
        @instance = nil
      end
    end

    def self.running?
      !!@instance
    end

    def initialize(config)
      @config = config
      @queue = Queue.new

      @instrumenter = Instrumenter.new(config, self)
      @error_builder = ErrorBuilder.new(config)

      @serializers = Struct.new(:transactions, :errors).new(
        Serializers::Transactions.new(config),
        Serializers::Errors.new(config)
      )
    end

    attr_reader :config, :queue, :instrumenter

    def start
      debug 'Starting agent'

      @instrumenter.start

      boot_worker

      config.enabled_injectors.each do |lib|
        require "elastic_apm/injectors/#{lib}"
      end

      self
    end

    def stop
      debug 'Stopping agent'

      @instrumenter.stop

      kill_worker

      self
    end

    at_exit do
      stop
    end

    def enqueue_transactions(transactions)
      data = @serializers.transactions.build(Array(transactions))
      @queue << Worker::Request.new('/v1/transactions', data)
    end

    def enqueue_errors(errors)
      data = @serializers.errors.build(Array(errors))
      @queue << Worker::Request.new('/v1/errors', data)
    end

    # instrumentation

    def current_transaction
      instrumenter.current_transaction
    end

    def transaction(*args, &block)
      instrumenter.transaction(*args, &block)
    end

    def span(*args, &block)
      instrumenter.span(*args, &block)
    end

    # errors

    def report(exception, rack_env: nil)
      error = @error_builder.build(exception, rack_env: rack_env)
      enqueue_errors error
      error
    end

    private

    def boot_worker
      debug 'Booting worker in thread'

      @worker_thread = Thread.new do
        Worker.new(@config, @queue).run_forever
      end
    end

    def kill_worker
      @queue << Worker::StopMessage.new

      unless @worker_thread.join(5) # 5 secs
        raise 'Failed to wait for worker, not all messages sent'
      end

      @worker_thread = nil

      debug 'Killed worker'
    end
  end
  # rubocop:enable Metrics/ClassLength
end
