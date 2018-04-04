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
      def initialize
        self.current = nil
      end

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

      @subscriber = subscriber_class.new(config)
    end

    attr_reader :config, :pending_transactions

    def start
      @subscriber.register!
    end

    def stop
      current_transaction.release if current_transaction
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

      if args.last.is_a? Hash
        args.last[:sampled] = random_sample?
      else
        args.push(sampled: random_sample?)
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

    def random_sample?
      rand <= config.transaction_sample_rate
    end

    def span(*args, &block)
      unless current_transaction
        return yield if block_given?
        return
      end

      current_transaction.span(*args, &block)
    end

    def set_tag(key, value)
      return unless current_transaction
      current_transaction.context.tags[key] = value.to_s
    end

    def set_custom_context(context)
      return unless current_transaction
      current_transaction.context.custom.merge!(context)
    end

    def set_user(user)
      return unless current_transaction
      current_transaction.context.user = Context::User.new(config, user)
    end

    def submit_transaction(transaction)
      @agent.enqueue_transaction transaction

      return unless config.debug_transactions
      debug('Submitted transaction:') { Util.inspect_transaction transaction }
    end

    def inspect
      '<ElasticAPM::Instrumenter ' \
        "current_transaction=#{current_transaction.inspect}" \
        '>'
    end
  end
end
