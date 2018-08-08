# frozen_string_literal: true

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

    def initialize(agent)
      @agent = agent
      @config = agent.config

      @transaction_info = TransactionInfo.new
    end

    attr_reader :agent, :config, :pending_transactions

    def start
    end

    def stop
      current_transaction.release if current_transaction
      @subscriber.unregister! if @subscriber
    end

    def subscriber=(subscriber)
      @subscriber = subscriber
      @subscriber.register!
    end

    def current_transaction
      @transaction_info.current
    end

    def current_transaction=(transaction)
      @transaction_info.current = transaction
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/CyclomaticComplexity
    def transaction(name = nil, type = nil, context: nil, sampled: nil)
      unless config.instrument
        yield if block_given?
        return
      end

      if (transaction = current_transaction)
        yield transaction if block_given?
        return transaction
      end

      sampled = random_sample? if sampled.nil?

      transaction =
        Transaction.new self, name, type, context: context, sampled: sampled

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
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/MethodLength

    def random_sample?
      rand <= config.transaction_sample_rate
    end

    # rubocop:disable Metrics/MethodLength
    def span(name, type = nil, backtrace: nil, context: nil, &block)
      unless current_transaction
        return yield if block_given?
        return
      end

      current_transaction.span(
        name,
        type,
        backtrace: backtrace,
        context: context,
        &block
      )
    end
    # rubocop:enable Metrics/MethodLength

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
      agent.enqueue_transaction transaction

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
