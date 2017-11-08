# frozen_string_literal: true

module ElasticAPM
  # @api private
  # rubocop:disable Metrics/ClassLength
  class Agent
    include Log

    KEY = :__elastic_transaction_key
    LOCK = Mutex.new

    # @api private
    class TransactionInfo
      def current
        Thread.current[KEY]
      end

      def current=(transaction)
        Thread.current[KEY] = transaction
      end
    end

    # life cycle

    def self.instance # rubocop:disable Style/TrivialAccessors
      @instance
    end

    def self.start(config = {})
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

    def self.started?
      !!@instance
    end

    def initialize(config)
      @config = config

      @transaction_info = TransactionInfo.new

      @serializers = Struct.new(:transactions).new(
        Serializers::Transactions.new(config)
      )

      @subscriber = Subscriber.new(self)

      @queue = Queue.new
      @pending_transactions = []
      @last_sent_transactions = Time.now.utc
    end

    attr_reader :config, :queue, :pending_transactions

    def start
      debug 'Starting agent'

      boot_worker
      @subscriber.register!

      config.enabled_injectors.each do |lib|
        require "elastic_apm/injectors/#{lib}"
      end

      self
    end

    def stop
      debug 'Stopping agent'

      @subscriber.unregister!
      kill_worker

      self
    end

    at_exit do
      stop
    end

    # instrumentation

    def current_transaction
      @transaction_info.current
    end

    def current_transaction=(transaction)
      @transaction_info.current = transaction
    end

    # rubocop:disable Metrics/MethodLength
    def transaction(*args)
      if (transaction = current_transaction)
        yield transaction if block_given?
        return transaction
      end

      transaction = Transaction.new self, *args

      self.current_transaction = transaction
      return transaction unless block_given?

      begin
        yield transaction
      ensure
        self.current_transaction = nil
        transaction.done
      end

      transaction
    end
    # rubocop:enable Metrics/MethodLength

    def trace(*args, &block)
      transaction.trace(*args, &block)
    end

    def submit_transaction(transaction)
      @pending_transactions << transaction

      if config.debug_transactions
        debug('Submitted transaction:') { Util.inspect_transaction transaction }
      end

      return unless should_send_transactions?
      flush_transactions
    end

    private

    def boot_worker
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
    end

    def should_send_transactions?
      interval = config.transaction_send_interval
      return true unless interval
      Time.now.utc - @last_sent_transactions >= interval
    end

    def flush_transactions
      return if @pending_transactions.empty?

      data = @serializers.transactions.build(@pending_transactions)
      @queue << Worker::Request.new('/v1/transactions', data)

      @last_sent_transactions = Time.now.utc
      @pending_transactions = []

      true
    end
  end
  # rubocop:enable Metrics/ClassLength
end
