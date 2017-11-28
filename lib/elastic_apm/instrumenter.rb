# frozen_string_literal: true

require 'elastic_apm/subscriber'
require 'elastic_apm/span'
require 'elastic_apm/transaction'

module ElasticAPM
  # @api private
  class Instrumenter
    include Log

    KEY = :__elastic_transaction_key

    # @api private
    class TransactionInfo
      def current
        Thread.current[KEY]
      end

      def current=(transaction)
        Thread.current[KEY] = transaction
      end
    end

    def initialize(config, agent, subscriber_class: Subscriber)
      @config = config
      @agent = agent

      @transaction_info = TransactionInfo.new

      @subscriber = subscriber_class.new(self)

      @pending_transactions = []
      @last_sent_transactions = Time.now.utc
    end

    attr_reader :config, :pending_transactions

    def start
      @subscriber.register!
    end

    def stop
      current_transaction&.release
      @subscriber.unregister!
    end

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

    def span(*args, &block)
      transaction.span(*args, &block)
    end

    def submit_transaction(transaction)
      @pending_transactions << transaction

      if config.debug_transactions
        debug('Submitted transaction:') { Util.inspect_transaction transaction }
      end

      return unless should_flush_transactions?
      flush_transactions
    end

    def should_flush_transactions?
      return true unless (interval = config.transaction_send_interval)
      Time.now.utc - @last_sent_transactions >= interval
    end

    def flush_transactions
      return if @pending_transactions.empty?

      debug 'Flushing transactions'

      @agent.enqueue_transactions @pending_transactions

      @last_sent_transactions = Time.now.utc
      @pending_transactions = []

      true
    end
  end
end
