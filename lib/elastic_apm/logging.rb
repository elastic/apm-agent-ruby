# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Logging
    PREFIX = '[ElasticAPM] '

    LEVELS = {
      debug: Logger::DEBUG,
      info: Logger::INFO,
      warn: Logger::WARN,
      error: Logger::ERROR,
      fatal: Logger::FATAL
    }.freeze

    def debug(msg, *args, &block)
      log(:debug, msg, *args, &block)
    end

    def info(msg, *args, &block)
      log(:info, msg, *args, &block)
    end

    def warn(msg, *args, &block)
      log(:warn, msg, *args, &block)
    end

    def error(msg, *args, &block)
      log(:error, msg, *args, &block)
    end

    def fatal(msg, *args, &block)
      log(:fatal, msg, *args, &block)
    end

    private

    def log(lvl, msg, *args)
      return unless (logger = @config&.logger)
      return unless LEVELS[lvl] >= (@config&.log_level || 0)

      formatted_msg = prepend_prefix(format(msg.to_s, *args))

      return logger.send(lvl, formatted_msg) unless block_given?

      logger.send(lvl, "#{formatted_msg}\n#{yield}")
    end

    def prepend_prefix(str)
      "#{PREFIX}#{str}"
    end
  end
end
