# frozen_string_literal: true

require 'securerandom'

require 'elastic_apm/span/context'

module ElasticAPM
  # @api private
  class Span
    DEFAULT_TYPE = 'custom'

    # rubocop:disable Metrics/MethodLength
    def initialize(
      transaction,
      name,
      type = nil,
      parent: nil,
      context: nil
    )
      @transaction = transaction
      @name = name
      @type = type || DEFAULT_TYPE
      @parent = parent
      @context = context

      @id = SecureRandom.hex(8)
      @trace_id = transaction.trace_id
      @transaction_id = transaction.id

      @timestamp = @transaction.timestamp

      @stacktrace = nil
      @original_backtrace = nil
    end
    # rubocop:enable Metrics/MethodLength

    attr_accessor :name, :type, :original_backtrace
    attr_reader :id, :context, :stacktrace, :duration, :parent, :relative_start,
      :timestamp, :transaction_id, :trace_id

    def start
      @relative_start = Util.micros - @timestamp

      self
    end

    def done
      @duration = Util.micros - @transaction.timestamp - relative_start

      if original_backtrace && long_enough_for_stacktrace?
        @stacktrace =
          @transaction.instrumenter.agent.stacktrace_builder.build(
            original_backtrace, type: :span
          )
      end

      self.original_backtrace = nil # release it

      self
    end

    def done?
      !!duration
    end

    def running?
      relative_start && !done?
    end

    def parent_id
      parent&.id || @transaction&.id
    end

    def inspect
      "<ElasticAPM::Span id:#{id}" \
        " name:#{name.inspect}" \
        " type:#{type.inspect}" \
        '>'
    end

    private

    def long_enough_for_stacktrace?
      min_duration = @transaction.instrumenter.config.span_frames_min_duration

      case min_duration
      when -1 then true
      when 0 then false
      else duration / 1000 >= min_duration
      end
    end
  end
end
