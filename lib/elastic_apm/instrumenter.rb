# frozen_string_literal: true

require 'elastic_apm/span'
require 'elastic_apm/transaction'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Instrumenter
    include Logging

    TRANSACTION_KEY = :__elastic_transaction_key
    SPAN_KEY = :__elastic_span_key

    # @api private
    class Current
      def initialize
        self.transaction = nil
      end

      def transaction
        Thread.current[TRANSACTION_KEY]
      end

      def transaction=(transaction)
        Thread.current[TRANSACTION_KEY] = transaction
      end

      def span
        Thread.current[SPAN_KEY]
      end

      def span=(span)
        Thread.current[SPAN_KEY] = span
      end
    end

    def initialize(agent)
      @agent = agent
      @config = agent.config

      @current = Current.new
    end

    attr_reader :agent, :config, :pending_transactions

    def start
    end

    def stop
      self.current_transaction = nil
      self.current_span = nil

      @subscriber.unregister! if @subscriber
    end

    def subscriber=(subscriber)
      @subscriber = subscriber
      @subscriber.register!
    end

    # transactions

    def current_transaction
      @current.transaction
    end

    def current_transaction=(transaction)
      @current.transaction = transaction
    end

    # rubocop:disable Metrics/MethodLength
    def start_transaction(
      name = nil,
      type = nil,
      context: nil,
      traceparent: nil
    )
      return nil unless config.instrument?

      if (transaction = current_transaction)
        raise ExistingTransactionError,
          "Transactions may not be nested.\nAlready inside #{transaction}"
      end

      sampled = traceparent ? traceparent.recorded? : random_sample?

      transaction =
        Transaction.new(
          name,
          type,
          context: context,
          traceparent: traceparent,
          sampled: sampled
        )

      transaction.start

      self.current_transaction = transaction
    end
    # rubocop:enable Metrics/MethodLength

    def end_transaction(result = nil)
      return nil unless (transaction = current_transaction)

      self.current_transaction = nil

      transaction.stop
      transaction.done result

      agent.enqueue transaction

      transaction
    end

    # spans

    def current_span
      @current.span
    end

    def current_span=(span)
      @current.span = span
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def start_span(name, type = nil, backtrace: nil, context: nil)
      return unless (transaction = current_transaction)
      return unless transaction.sampled?

      transaction.inc_started_spans!

      if transaction.max_spans_reached?(config)
        transaction.inc_dropped_spans!
        return
      end

      span = Span.new(
        name,
        type,
        transaction: transaction,
        parent: current_span || transaction,
        context: context
      )

      if backtrace && span_frames_min_duration?
        span.original_backtrace = backtrace
      end

      self.current_span = span

      span.start
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    def end_span
      return unless (span = current_span)

      span.done

      self.current_span =
        span.parent&.is_a?(Span) && span.parent || nil

      agent.enqueue span
    end

    # metadata

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
      agent.enqueue transaction
    end

    def inspect
      '<ElasticAPM::Instrumenter ' \
        "current_transaction=#{current_transaction.inspect}" \
        '>'
    end

    private

    def random_sample?
      rand <= config.transaction_sample_rate
    end

    def span_frames_min_duration?
      @agent.config.span_frames_min_duration != 0
    end
  end
  # rubocop:enable Metrics/ClassLength
end
