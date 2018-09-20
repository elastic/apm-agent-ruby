# frozen_string_literal: true

require 'securerandom'

module ElasticAPM
  # @api private
  class Transaction
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

    attr_accessor :name, :type, :result
    attr_reader :id, :context, :duration, :started_spans, :dropped_spans,
      :timestamp, :notifications, :sampled, :instrumenter, :trace_id

    def stop
      @duration = Util.micros - @timestamp
    end

    def done(result = nil)
      stop

      self.result = result if result

      self
    end

    def done?
      !!@duration
    end

    def sampled?
      !!sampled
    end

    def add_response(*args)
      context.response = Context::Response.new(*args)
    end

    # spans

    def inc_started_spans!
      @started_spans += 1
    end

    def inc_dropped_spans!
      @dropped_spans += 1
    end

    def max_spans_reached?
      started_spans > instrumenter.config.transaction_max_spans
    end

    def next_span_id
      @span_id_ticker += 1
    end

    def inspect
      "<ElasticAPM::Transaction id:#{id}" \
        " name:#{name.inspect} type:#{type.inspect}>"
    end
  end
end
