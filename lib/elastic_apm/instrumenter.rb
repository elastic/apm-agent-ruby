# frozen_string_literal: true

require 'elastic_apm/trace_context'
require 'elastic_apm/span'
require 'elastic_apm/transaction'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Instrumenter
    TRANSACTION_KEY = :__elastic_instrumenter_transaction_key
    SPAN_KEY = :__elastic_instrumenter_spans_key

    include Logging

    # @api private
    class Current
      def initialize
        self.transaction = nil
        self.spans = []
      end

      def transaction
        Thread.current[TRANSACTION_KEY]
      end

      def transaction=(transaction)
        Thread.current[TRANSACTION_KEY] = transaction
      end

      def spans
        Thread.current[SPAN_KEY] ||= []
      end

      def spans=(spans)
        Thread.current[SPAN_KEY] ||= []
        Thread.current[SPAN_KEY] = spans
      end
    end

    def initialize(config, stacktrace_builder:, &enqueue)
      @config = config
      @stacktrace_builder = stacktrace_builder
      @enqueue = enqueue

      @current = Current.new
    end

    attr_reader :config, :stacktrace_builder, :enqueue

    def start
      debug 'Starting instrumenter'
    end

    def stop
      debug 'Stopping instrumenter'

      self.current_transaction = nil
      current_spans.pop until current_spans.empty?

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
      trace_context: nil
    )
      return nil unless config.instrument?

      if (transaction = current_transaction)
        raise ExistingTransactionError,
          "Transactions may not be nested.\nAlready inside #{transaction}"
      end

      sampled = trace_context ? trace_context.recorded? : random_sample?

      transaction =
        Transaction.new(
          name,
          type,
          context: context,
          trace_context: trace_context,
          sampled: sampled
        )

      transaction.start

      self.current_transaction = transaction
    end
    # rubocop:enable Metrics/MethodLength

    def end_transaction(result = nil)
      return nil unless (transaction = current_transaction)

      self.current_transaction = nil

      transaction.done result

      enqueue.call transaction

      transaction
    end

    # spans

    def current_spans
      @current.spans
    end

    def current_span
      current_spans.last
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
    def start_span(
      name,
      type = nil,
      backtrace: nil,
      context: nil,
      trace_context: nil
    )
      return unless (transaction = current_transaction)
      return unless transaction.sampled?

      transaction.inc_started_spans!

      if transaction.max_spans_reached?(config)
        transaction.inc_dropped_spans!
        return
      end

      parent = current_span || transaction

      span = Span.new(
        name,
        type,
        transaction_id: transaction.id,
        parent_id: parent.id,
        context: context,
        stacktrace_builder: stacktrace_builder,
        trace_context: trace_context || parent.trace_context.child
      )

      if backtrace && config.span_frames_min_duration?
        span.original_backtrace = backtrace
      end

      current_spans.push span

      span.start
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    def end_span
      return unless (span = current_spans.pop)

      span.done

      enqueue.call span

      span
    end

    # metadata

    def set_tag(key, value)
      return unless current_transaction

      key = key.to_s.gsub(/[\."\*]/, '_').to_sym
      current_transaction.context.tags[key] = value.to_s
    end

    def set_custom_context(context)
      return unless current_transaction
      current_transaction.context.custom.merge!(context)
    end

    def set_user(user)
      return unless current_transaction
      current_transaction.context.user = Context::User.infer(config, user)
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
  end
  # rubocop:enable Metrics/ClassLength
end
