# frozen_string_literal: true

require 'securerandom'
require 'forwardable'

module ElasticAPM
  # @api private
  class Transaction
    extend Forwardable

    def_delegators :@trace_context,
      :trace_id, :parent_id, :id, :ensure_parent_id

    DEFAULT_TYPE = 'custom'

    # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
    def initialize(
      name = nil,
      type = nil,
      sampled: true,
      context: nil,
      config:,
      trace_context: nil
    )
      @name = name
      @type = type || DEFAULT_TYPE
      @config = config

      @sampled = sampled

      @context = context || Context.new # TODO: Lazy generate this?
      if config.default_labels
        Util.reverse_merge!(@context.labels, config.default_labels)
      end

      @trace_context = trace_context || TraceContext.new(recorded: sampled)

      @started_spans = 0
      @dropped_spans = 0

      @notifications = [] # for AS::Notifications
    end
    # rubocop:enable Metrics/ParameterLists, Metrics/MethodLength

    attr_accessor :name, :type, :result

    attr_reader :context, :duration, :started_spans, :dropped_spans,
      :timestamp, :trace_context, :notifications, :config

    def sampled?
      @sampled
    end

    def stopped?
      !!duration
    end

    # life cycle

    def start(clock_start = Util.monotonic_micros)
      @timestamp = Util.micros
      @clock_start = clock_start
      self
    end

    def stop(clock_end = Util.monotonic_micros)
      raise 'Transaction not yet start' unless timestamp
      @duration = clock_end - @clock_start
      self
    end

    def done(result = nil, clock_end: Util.monotonic_micros)
      stop clock_end
      self.result = result if result
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
      started_spans > config.transaction_max_spans
    end

    # context

    def add_response(*args)
      context.response = Context::Response.new(*args)
    end

    def set_user(user)
      context.user = Context::User.infer(config, user)
    end

    def inspect
      "<ElasticAPM::Transaction id:#{id}" \
        " name:#{name.inspect} type:#{type.inspect}>"
    end
  end
end
