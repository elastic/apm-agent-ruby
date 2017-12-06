# frozen_string_literal: true

require 'logger'

module ElasticAPM
  # @api private
  # TODO
  class Config
    DEFAULTS = {
      app_name: 'ruby',
      server: 'http://localhost:8200',
      secret_token: nil,
      timeout: 10,
      open_timeout: 10,

      log_path: '-',
      log_level: Logger::INFO,

      transaction_send_interval: 60,
      debug_transactions: false,
      debug_http: false,

      enabled_injectors: %w[net_http],

      view_paths: []
    }.freeze

    LOCK = Mutex.new

    def initialize(options = nil)
      options = {} if options.nil?

      DEFAULTS.merge(options).each do |key, value|
        send("#{key}=", value)
      end

      return unless block_given?

      yield self
    end

    attr_accessor :app_name
    attr_accessor :server
    attr_accessor :secret_token
    attr_accessor :timeout
    attr_accessor :open_timeout

    attr_accessor :log_path
    attr_accessor :log_level

    attr_accessor :transaction_send_interval
    attr_accessor :debug_transactions
    attr_accessor :debug_http

    attr_accessor :enabled_injectors

    attr_accessor :view_paths

    def logger
      @logger ||=
        LOCK.synchronize do
          build_logger(log_path, log_level)
        end
    end

    def use_ssl?
      server.start_with?('https')
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
