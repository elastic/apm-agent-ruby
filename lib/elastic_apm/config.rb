# frozen_string_literal: true

require 'logger'

module ElasticAPM
  # @api private
  # TODO
  class Config
    DEFAULTS = {
      server: 'http://localhost:8200',

      log_path: '-',
      log_level: Logger::INFO,

      transaction_send_interval: 60,
      debug_transactions: false,

      enabled_injectors: %w[redis],

      view_paths: []
    }.freeze

    def initialize(options = nil)
      options = {} if options.nil?

      DEFAULTS.merge(options).each do |key, value|
        send("#{key}=", value)
      end

      return unless block_given?

      yield self
    end

    attr_accessor :server

    attr_accessor :log_path
    attr_accessor :log_level

    attr_accessor :transaction_send_interval
    attr_accessor :debug_transactions

    attr_accessor :enabled_injectors

    attr_accessor :view_paths

    def logger
      @logger ||= build_logger(log_path, log_level)
    end

    attr_writer :logger

    private

    def build_logger(path, level)
      logger = Logger.new(path == '-' ? STDOUT : path)
      logger.level = level
      logger
    end
  end
end
