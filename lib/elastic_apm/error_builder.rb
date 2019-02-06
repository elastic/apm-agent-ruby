# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ErrorBuilder
    def initialize(agent)
      @agent = agent
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def build_exception(exception, handled: true)
      error = Error.new
      error.exception = Error::Exception.new(exception, handled: handled)

      if exception.backtrace
        add_stacktrace error, :exception, exception.backtrace
      end

      add_current_transaction_fields error

      if (transaction = ElasticAPM.current_transaction)
        error.context = transaction.context.dup
        error.trace_id = transaction.trace_id
        error.transaction_id = transaction.id
        error.parent_id = ElasticAPM.current_span&.id || transaction.id
      end

      error
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def build_log(message, backtrace: nil, **attrs)
      error = Error.new
      error.log = Error::Log.new(message, **attrs)

      if backtrace
        add_stacktrace error, :log, backtrace
      end

      add_current_transaction_fields error

      error
    end

    private

    def add_stacktrace(error, kind, backtrace)
      stacktrace =
        @agent.stacktrace_builder.build(backtrace, type: :error)
      return unless stacktrace

      case kind
      when :exception
        error.exception.stacktrace = stacktrace
      when :log
        error.log.stacktrace = stacktrace
      end

      error.culprit = stacktrace.frames.first.function
    end

    def add_current_transaction_fields(error)
      return unless (transaction = ElasticAPM.current_transaction)
      error.transaction_id = transaction.id
      error.transaction = { sampled: transaction.sampled? }
    end
  end
end
