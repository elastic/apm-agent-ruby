# frozen_string_literal: true

module ElasticAPM
  # @api private
  class PrefixedLogger < Logger
    def initialize(logdev, prefix: '', **args)
      super(logdev, **args)

      @prefix = prefix
    end

    attr_reader :prefix

    def add(severity, message = nil, progname = nil, &block)
      super(severity, message, format('%s%s', prefix, progname), &block)
    end
  end
end
