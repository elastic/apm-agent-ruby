# frozen_string_literal: true

require 'elastic_apm/span/context'

module ElasticAPM
  # @api private
  class Span
    extend Forwardable

    def_delegators :@trace_context, :trace_id, :parent_id, :id

    DEFAULT_TYPE = 'custom'

    # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
    def initialize(
      name:,
      transaction_id:,
      trace_context:,
      type: nil,
      subtype: nil,
      action: nil,
      context: nil,
      stacktrace_builder: nil
    )
      @name = name

      if subtype.nil? && type&.include?('.')
        @type, @subtype, @action = type.split('.')
      else
        @type = type || DEFAULT_TYPE
        @subtype = subtype
        @action = action
      end

      @transaction_id = transaction_id
      @trace_context = trace_context

      @context = context || Span::Context.new
      @stacktrace_builder = stacktrace_builder
    end
    # rubocop:enable Metrics/ParameterLists, Metrics/MethodLength

    attr_accessor(
      :action,
      :name,
      :original_backtrace,
      :subtype,
      :trace_context,
      :type
    )
    attr_reader(
      :context,
      :duration,
      :stacktrace,
      :timestamp,
      :transaction_id
    )

    # life cycle

    def start(clock_start = Util.monotonic_micros)
      @timestamp = Util.micros
      @clock_start = clock_start
      self
    end

    def stop(clock_end = Util.monotonic_micros)
      @duration ||= (clock_end - @clock_start)
      self
    end

    def done(clock_end: Util.monotonic_micros)
      stop clock_end

      build_stacktrace! if should_build_stacktrace?
      self.original_backtrace = nil # release original

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
