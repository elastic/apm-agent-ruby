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

    def get_headers(rack_env)
      # In Rails < 5 ActionDispatch::Request inherits from Hash
      rack_env.respond_to?(:headers) ? rack_env.headers : rack_env
    end
  end
end
