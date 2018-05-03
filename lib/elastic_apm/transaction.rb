# frozen_string_literal: true

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Transaction
    DEFAULT_TYPE = 'custom'.freeze

    # rubocop:disable Metrics/MethodLength
    def initialize(
      instrumenter,
      name = nil,
      type = nil,
      context: nil,
      sampled: true
    )
      @id = SecureRandom.uuid
      @instrumenter = instrumenter
      @name = name
      @type = type || DEFAULT_TYPE

      @timestamp = Util.micros

      @spans = []
      @span_id_ticker = -1
      @dropped_spans = 0

      @notifications = [] # for AS::Notifications

      @context = context || Context.new

      @sampled = sampled

      yield self if block_given?
    end
    # rubocop:enable Metrics/MethodLength

    attr_accessor :id, :name, :result, :type
    attr_reader :context, :duration, :dropped_spans, :root_span, :timestamp,
      :spans, :notifications, :sampled, :instrumenter

    def release
      @instrumenter.current_transaction = nil
    end

    def done(result = nil)
      @duration = Util.micros - @timestamp
      @result = result

      self
    end

    def done?
      !!(@result && @duration)
    end

    def submit(result = nil, status: nil, headers: {})
      done result

      if status
        context.response = Context::Response.new(status, headers: headers)
      end

      release

      @instrumenter.submit_transaction self

      self
    end

    def running_spans
      spans.select(&:running?)
    end

    # rubocop:disable Metrics/MethodLength
    def span(name, type = nil, backtrace: nil, context: nil)
      unless sampled?
        return yield if block_given?
        return
      end

      if spans.length >= instrumenter.config.transaction_max_spans
        @dropped_spans += 1

        return yield if block_given?
        return
      end

      span = build_and_start_span(name, type, context, backtrace)

      return span unless block_given?

      begin
        result = yield span
      ensure
        span.done
      end

      result
    end
    # rubocop:enable Metrics/MethodLength

    def build_and_start_span(name, type, context, backtrace)
      span = next_span(name, type, context)
      spans << span

      if backtrace
        span.stacktrace =
          @instrumenter.agent.stacktrace_builder.build(backtrace, type: :span)
      end

      span.start
    end

    def current_span
      spans.reverse.lazy.find(&:running?)
    end

    def sampled?
      !!sampled
    end

    def inspect
      "<ElasticAPM::Transaction id:#{id}" \
        " name:#{name.inspect}" \
        " type:#{type.inspect}" \
        '>'
    end

    private

    def next_span_id
      @span_id_ticker += 1
    end

    def next_span(name, type, context)
      Span.new(
        self,
        next_span_id,
        name,
        type,
        parent: current_span,
        context: context
      )
    end
  end
  # rubocop:enable Metrics/ClassLength
end
