# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ErrorBuilder
    def initialize(agent)
      @agent = agent
    end

    def build_exception(exception, context: nil, handled: true)
      error = Error.new context: context || Context.new
      error.exception = Error::Exception.new(exception, handled: handled)

      Util.reverse_merge!(error.context.labels, @agent.config.default_labels)

      if exception.backtrace
        add_stacktrace error, :exception, exception.backtrace
      end

      add_current_transaction_fields error, ElasticAPM.current_transaction

      error
    end

    def build_log(message, context: nil, backtrace: nil, **attrs)
      error = Error.new context: context || Context.new
      error.log = Error::Log.new(message, **attrs)

      if backtrace
        add_stacktrace error, :log, backtrace
      end

      add_current_transaction_fields error, ElasticAPM.current_transaction

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

      error.culprit = stacktrace.frames.first&.function
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def add_current_transaction_fields(error, transaction)
      return unless transaction

      error.transaction_id = transaction.id
      error.transaction = {
        sampled: transaction.sampled?,
        type: transaction.type
      }
      error.trace_id = transaction.trace_id
      error.parent_id = ElasticAPM.current_span&.id || transaction.id

      return unless transaction.context

      Util.reverse_merge!(error.context.labels, transaction.context.labels)
      Util.reverse_merge!(error.context.custom, transaction.context.custom)
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
end
