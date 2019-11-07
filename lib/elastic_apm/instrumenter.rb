# frozen_string_literal: true

require 'elastic_apm/trace_context'
require 'elastic_apm/child_durations'
require 'elastic_apm/span'
require 'elastic_apm/transaction'
require 'elastic_apm/span_helpers'

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

    def initialize(config, metrics:, stacktrace_builder:, &enqueue)
      @config = config
      @stacktrace_builder = stacktrace_builder
      @enqueue = enqueue
      @metrics = metrics

      @current = Current.new
    end

    attr_reader :stacktrace_builder, :enqueue

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
      debug 'Registering subscriber'
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
      config:,
      context: nil,
      trace_context: nil
    )
      return nil unless config.instrument?

      if (transaction = current_transaction)
        raise ExistingTransactionError,
          "Transactions may not be nested.\n" \
          "Already inside #{transaction.inspect}"
      end

      sampled = trace_context ? trace_context.recorded? : random_sample?(config)

      transaction =
        Transaction.new(
          name,
          type,
          context: context,
          trace_context: trace_context,
          sampled: sampled,
          config: config
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

      update_transaction_metrics(transaction)

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
    # rubocop:disable Metrics/ParameterLists
    def start_span(
      name,
      type = nil,
      subtype: nil,
      action: nil,
      backtrace: nil,
      context: nil,
      trace_context: nil
    )
      return unless (transaction = current_transaction)
      return unless transaction.sampled?

      transaction.inc_started_spans!

      if transaction.max_spans_reached?
        transaction.inc_dropped_spans!
        return
      end

      parent = current_span || transaction

      span = Span.new(
        name: name,
        subtype: subtype,
        action: action,
        transaction: transaction,
        parent: parent,
        trace_context: trace_context,
        type: type,
        context: context,
        stacktrace_builder: stacktrace_builder
      )

      if backtrace && transaction.config.span_frames_min_duration?
        span.original_backtrace = backtrace
      end

      current_spans.push span

      span.start
    end
    # rubocop:enable Metrics/ParameterLists
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    def end_span
      return unless (span = current_spans.pop)

      span.done

      enqueue.call span

      update_span_metrics(span)

      span
    end

    # metadata

    def set_label(key, value)
      return unless current_transaction

      key = key.to_s.gsub(/[\."\*]/, '_').to_sym
      current_transaction.context.labels[key] = value
    end

    def set_custom_context(context)
      return unless current_transaction
      current_transaction.context.custom.merge!(context)
    end

    def set_user(user)
      return unless current_transaction
      current_transaction.set_user(user)
    end

    def inspect
      '<ElasticAPM::Instrumenter ' \
        "current_transaction=#{current_transaction.inspect}" \
        '>'
    end

    private

    def random_sample?(config)
      rand <= config.transaction_sample_rate
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def update_transaction_metrics(transaction)
      return unless transaction.config.collect_metrics?

      tags = {
        'transaction.name': transaction.name,
        'transaction.type': transaction.type
      }

      @metrics.get(:transaction).timer(
        :'transaction.duration.sum.us',
        tags: tags, reset_on_collect: true
      ).update(transaction.duration)

      @metrics.get(:transaction).counter(
        :'transaction.duration.count',
        tags: tags, reset_on_collect: true
      ).inc!

      return unless transaction.sampled?
      return unless transaction.config.breakdown_metrics?

      @metrics.get(:breakdown).counter(
        :'transaction.breakdown.count',
        tags: tags, reset_on_collect: true
      ).inc!

      span_tags = tags.merge('span.type': 'app')

      @metrics.get(:breakdown).timer(
        :'span.self_time.sum.us',
        tags: span_tags, reset_on_collect: true
      ).update(transaction.self_time)

      @metrics.get(:breakdown).counter(
        :'span.self_time.count',
        tags: span_tags, reset_on_collect: true
      ).inc!
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def update_span_metrics(span)
      return unless span.transaction.config.breakdown_metrics?

      tags = {
        'span.type': span.type,
        'transaction.name': span.transaction.name,
        'transaction.type': span.transaction.type
      }

      tags[:'span.subtype'] = span.subtype if span.subtype

      @metrics.get(:breakdown).timer(
        :'span.self_time.sum.us',
        tags: tags, reset_on_collect: true
      ).update(span.self_time)

      @metrics.get(:breakdown).counter(
        :'span.self_time.count',
        tags: tags, reset_on_collect: true
      ).inc!
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
  # rubocop:enable Metrics/ClassLength
end
