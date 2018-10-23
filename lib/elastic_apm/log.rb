# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Log
    PREFIX = '[ElasticAPM] '

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

    def log(lvl, msg, *args)
      return unless logger

      formatted_msg = prepend_prefix(format(msg.to_s, *args))

      return logger.send(lvl, formatted_msg) unless block_given?

      # TODO: dont evaluate block if level is higher
      logger.send(lvl, "#{formatted_msg}\n#{yield}")
    end

    private

    def prepend_prefix(str)
      "#{PREFIX}#{str}"
    end

    def logger
      return false unless (config = instance_variable_get(:@config))
      config.logger
    end
  end
end
