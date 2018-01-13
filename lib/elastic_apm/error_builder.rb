# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ErrorBuilder
    def initialize(config)
      @config = config
    end

    attr_reader :config

    def build_exception(exception, handled: true)
      error = Error.new
      error.exception = Error::Exception.new(exception, handled: handled)

      add_stacktrace error, :exception, exception.backtrace
      add_transaction_id error

      if (transaction = ElasticAPM.current_transaction)
        error.context = transaction.context.dup
      end

      error
    end

    def build_log(message, backtrace: nil, **attrs)
      error = Error.new
      error.log = Error::Log.new(message, **attrs)

      add_stacktrace error, :log, backtrace
      add_transaction_id error

      error
    end

    private

    def add_stacktrace(error, kind, backtrace)
      return unless (stacktrace = Stacktrace.build(config, backtrace))

      case kind
      when :exception
        error.exception.stacktrace = stacktrace
      when :log
        error.log.stacktrace = stacktrace
      end

      error.culprit = stacktrace.frames.first.function
    end

    def add_transaction_id(error)
      return unless (transaction = ElasticAPM.current_transaction)
      error.transaction_id = transaction.id
    end
  end
end
