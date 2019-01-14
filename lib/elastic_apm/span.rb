# frozen_string_literal: true

require 'securerandom'

require 'elastic_apm/span/context'

module ElasticAPM
  # @api private
  class Span
    DEFAULT_TYPE = 'custom'

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      name,
      type = nil,
      transaction_id: nil,
      parent_id: nil,
      context: nil,
      stacktrace_builder: nil,
      trace_context: nil
    )
      @name = name
      @type = type || DEFAULT_TYPE

      @transaction_id = transaction_id

      @parent_id = parent_id
      @trace_context = trace_context || TraceContext.for_span

      @context = context || Span::Context.new
      @stacktrace_builder = stacktrace_builder
    end
    # rubocop:enable Metrics/ParameterLists

    attr_accessor :name, :type, :original_backtrace, :parent_id, :trace_context
    attr_reader :context, :stacktrace, :duration, :timestamp, :transaction_id

    def id
      trace_context&.span_id
    end

    def trace_id
      trace_context&.trace_id
    end

    # life cycle

    def start(timestamp = Util.micros)
      @timestamp = timestamp

      self
    end

    def stop(end_timestamp = Util.micros)
      @duration ||= (end_timestamp - timestamp)
    end

    def done(end_time: Util.micros)
      stop end_time

      build_stacktrace! if should_build_stacktrace?

      self
    end

    def stopped?
      !!duration
    end

    def started?
      !!timestamp
    end

    def running?
      started? && !stopped?
    end

    # relations

    def inspect
      "<ElasticAPM::Span id:#{id}" \
        " name:#{name.inspect}" \
        " type:#{type.inspect}" \
        '>'
    end

    private

    def build_stacktrace!
      @stacktrace = @stacktrace_builder.build(original_backtrace, type: :span)
      self.original_backtrace = nil # release original
    end

    def should_build_stacktrace?
      @stacktrace_builder && original_backtrace && long_enough_for_stacktrace?
    end

    def long_enough_for_stacktrace?
      min_duration =
        @stacktrace_builder.config.span_frames_min_duration_us

      return true if min_duration < 0
      return false if min_duration == 0

      duration >= min_duration
    end
  end
end
