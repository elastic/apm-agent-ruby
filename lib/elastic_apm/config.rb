# frozen_string_literal: true

require 'logger'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Config
    DEFAULTS = {
      server_url: 'http://localhost:8200',
      secret_token: nil,

      service_name: nil,
      service_version: nil,
      environment: ENV['RAILS_ENV'] || ENV['RACK_ENV'],
      framework_name: nil,
      framework_version: nil,

      log_path: '-',
      log_level: Logger::INFO,
      logger: nil,

      http_timeout: 10,
      http_open_timeout: 10,
      transaction_send_interval: 10,
      debug_transactions: false,
      debug_http: false,

      enabled_injectors: %w[net_http json],

      current_user_id_method: :id,
      current_user_email_method: :email,
      current_user_username_method: :username,

      view_paths: [],
      root_path: Dir.pwd
    }.freeze

    ENV_TO_KEY = {
      'ELASTIC_APM_SERVER_URL' => 'server_url',
      'ELASTIC_APM_SECRET_TOKEN' => 'secret_token',

      'ELASTIC_APM_SERVICE_NAME' => 'service_name',
      'ELASTIC_APM_SERVICE_VERSION' => 'service_version',
      'ELASTIC_APM_ENVIRONMENT' => 'environment',
      'ELASTIC_APM_FRAMEWORK_NAME' => 'framework_name',
      'ELASTIC_APM_FRAMEWORK_VERSION' => 'framework_version'
    }.freeze

    # rubocop:disable Metrics/MethodLength
    def initialize(options = nil)
      options = {} if options.nil?

      # Start with the defaults
      DEFAULTS.each do |key, value|
        send("#{key}=", value)
      end

      # Set options from ENV
      ENV_TO_KEY.each do |env_key, key|
        next unless (value = ENV[env_key])
        send("#{key}=", value)
      end

      # Set options from arguments
      options.each do |key, value|
        send("#{key}=", value)
      end

      yield self if block_given?
    end
    # rubocop:enable Metrics/MethodLength

    attr_accessor :server_url
    attr_accessor :secret_token

    attr_accessor :service_name
    attr_accessor :service_version
    attr_accessor :environment
    attr_accessor :framework_name
    attr_accessor :framework_version

    attr_accessor :log_path
    attr_accessor :log_level

    attr_accessor :http_timeout
    attr_accessor :http_open_timeout
    attr_accessor :transaction_send_interval
    attr_accessor :debug_transactions
    attr_accessor :debug_http

    attr_accessor :enabled_injectors

    attr_accessor :view_paths
    attr_accessor :root_path

    attr_accessor :current_user_method
    attr_accessor :current_user_id_method
    attr_accessor :current_user_email_method
    attr_accessor :current_user_username_method

    attr_reader   :logger

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def app=(app)
      case app_type?(app)
      when :sinatra
        self.service_name = format_name(service_name || app.to_s)
        self.framework_name = framework_name || 'Sinatra'
        self.framework_version = framework_version || Sinatra::VERSION
        self.enabled_injectors += %w[sinatra]
        self.root_path = Dir.pwd
      when :rails
        self.service_name = format_name(service_name || app.class.parent_name)
        self.framework_name = 'Ruby on Rails'
        self.framework_version = Rails::VERSION::STRING
        self.logger = Rails.logger
        self.root_path = Rails.root.to_s
        self.view_paths = app.config.paths['app/views'].existent
      else
        # TODO: define custom?
        self.service_name = 'ruby'
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def app_type?(app)
      if defined?(::Rails) && app.is_a?(Rails::Application)
        return :rails
      end

      if app.is_a?(Class) && app.superclass.to_s == 'Sinatra::Base'
        return :sinatra
      end

      nil
    end

    def use_ssl?
      server_url.start_with?('https')
    end

    def logger=(logger)
      @logger = logger || build_logger(log_path, log_level)
    end

    private

    def build_logger(path, level)
      logger = Logger.new(path == '-' ? STDOUT : path)
      logger.level = level
      logger
    end

    def format_name(str)
      str.gsub('::', '_')
    end
  end
  # rubocop:enable Metrics/ClassLength
end
