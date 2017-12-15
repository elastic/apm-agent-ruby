# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ErrorBuilder
    def initialize(config)
      @config = config
    end

    attr_reader :config

    def build_exception(exception, rack_env: nil, handled: true)
      error = Error.new
      error.exception = Error::Exception.new(exception, handled: handled)

      if (stacktrace = Stacktrace.build(config, exception.backtrace))
        error.exception.stacktrace = stacktrace
        error.culprit = stacktrace.frames.last.function
      end

      if rack_env
        error.context.request = Error::Context::Request.from_rack_env rack_env
      end

      error
    end

    def build_log(message, backtrace: nil, **attrs)
      error = Error.new
      error.log = Error::Log.new(message, **attrs)

      if (stacktrace = Stacktrace.build(config, backtrace))
        error.log.stacktrace = stacktrace
        error.culprit = stacktrace.frames.last.function
      end

      error
    end
  end
end
