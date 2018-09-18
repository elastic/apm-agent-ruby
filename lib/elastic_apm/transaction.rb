# frozen_string_literal: true

require 'securerandom'

module ElasticAPM
  # @api private
  class Transaction # rubocop:disable Metrics/ClassLength
    DEFAULT_TYPE = 'custom'

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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

      @span_id_ticker = -1

      @started_spans = 0
      @dropped_spans = 0

      @notifications = [] # for AS::Notifications

      @context = context || Context.new
      @context.tags.merge!(instrumenter.config.default_tags) { |_, old, _| old }

      @sampled = sampled

      @trace_id = SecureRandom.hex(128)

      yield self if block_given?
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    attr_accessor :name, :type
    attr_reader :id, :context, :duration, :started_spans, :dropped_spans,
      :root_span, :timestamp, :result, :notifications, :sampled,
      :instrumenter, :trace_id

    def release
      @instrumenter.current_transaction = nil
    end

    def stop
      @duration = Util.micros - @timestamp
    end

    def done(result = nil, status: nil, headers: {})
      stop

      @result = result

      if status
        context.response = Context::Response.new(status, headers: headers)
      end

      self
    end

    def done?
      !!@duration
    end

    def sampled?
      !!sampled
    end

    def submit(result = nil, status: nil, headers: {})
      done(result, status: status, headers: headers) unless duration

      release

      @instrumenter.submit_transaction self

      self
    end

    # spans

    def inc_started_spans!
      @started_spans += 1
    end

    def inc_dropped_spans!
      @dropped_spans += 1
    end

    def max_spans_reached?
      started_spans >= instrumenter.config.transaction_max_spans
    end

    def next_span_id
      # TODO: This should follow new id rules
      @span_id_ticker += 1
    end

    def inspect
      "<ElasticAPM::Transaction id:#{id}" \
        " name:#{name.inspect} type:#{type.inspect}>"
    end
  end
end
