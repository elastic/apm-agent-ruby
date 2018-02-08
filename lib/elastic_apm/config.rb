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
      hostname: nil,

      log_path: '-',
      log_level: Logger::INFO,
      logger: nil,

      max_queue_size: 500,
      flush_interval: 10,
      transaction_sample_rate: 1.0,

      http_timeout: 10,
      http_open_timeout: 10,
      debug_transactions: false,
      debug_http: false,

      source_lines_error_app_frames: 5,
      source_lines_span_app_frames: 5,
      source_lines_error_library_frames: 0,
      source_lines_span_library_frames: 0,

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
      'ELASTIC_APM_FRAMEWORK_VERSION' => 'framework_version',
      'ELASTIC_APM_HOSTNAME' => 'hostname',

      'ELASTIC_APM_SOURCE_LINES_ERROR_APP_FRAMES' =>
        [:int, 'source_lines_error_app_frames'],
      'ELASTIC_APM_SOURCE_LINES_SPAN_APP_FRAMES' =>
        [:int, 'source_lines_span_app_frames'],
      'ELASTIC_APM_SOURCE_LINES_ERROR_LIBRARY_FRAMES' =>
        [:int, 'source_lines_error_library_frames'],
      'ELASTIC_APM_SOURCE_LINES_SPAN_LIBRARY_FRAMES' =>
        [:int, 'source_lines_span_library_frames'],

      'ELASTIC_APM_MAX_QUEUE_SIZE' => [:int, 'max_queue_size'],
      'ELASTIC_APM_FLUSH_INTERVAL' => 'flush_interval',
      'ELASTIC_APM_TRANSACTION_SAMPLE_RATE' =>
        [:float, 'transaction_sample_rate']
    }.freeze

    def initialize(options = nil)
      options = {} if options.nil?

      set_defaults
      set_from_env
      set_from_args(options)

      yield self if block_given?
    end

    attr_accessor :server_url
    attr_accessor :secret_token

    attr_accessor :service_name
    attr_accessor :service_version
    attr_accessor :environment
    attr_accessor :framework_name
    attr_accessor :framework_version
    attr_accessor :hostname

    attr_accessor :log_path
    attr_accessor :log_level

    attr_accessor :max_queue_size
    attr_accessor :flush_interval
    attr_accessor :transaction_sample_rate

    attr_accessor :http_timeout
    attr_accessor :http_open_timeout
    attr_accessor :debug_transactions
    attr_accessor :debug_http

    attr_accessor :source_lines_error_app_frames
    attr_accessor :source_lines_span_app_frames
    attr_accessor :source_lines_error_library_frames
    attr_accessor :source_lines_span_library_frames

    attr_accessor :enabled_injectors

    attr_accessor :view_paths
    attr_accessor :root_path

    attr_accessor :current_user_method
    attr_accessor :current_user_id_method
    attr_accessor :current_user_email_method
    attr_accessor :current_user_username_method

    attr_reader   :logger
    def app=(app)
      case app_type?(app)
      when :sinatra
        set_sinatra(app)
      when :rails
        set_rails(app)
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

    def set_defaults
      DEFAULTS.each do |key, value|
        send("#{key}=", value)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def set_from_env
      ENV_TO_KEY.each do |env_key, key|
        next unless (value = ENV[env_key])

        type, key = key if key.is_a? Array

        case type
        when :int
          send("#{key}=", value.to_i)
        when :float
          send("#{key}=", value.to_f)
        else
          send("#{key}=", value)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def set_from_args(options)
      options.each do |key, value|
        send("#{key}=", value)
      end
    end

    def set_sinatra(app)
      self.service_name = format_name(service_name || app.to_s)
      self.framework_name = framework_name || 'Sinatra'
      self.framework_version = framework_version || Sinatra::VERSION
      self.enabled_injectors += %w[sinatra]
      self.root_path = Dir.pwd
    end

    def set_rails(app)
      self.service_name = format_name(service_name || app.class.parent_name)
      self.framework_name = 'Ruby on Rails'
      self.framework_version = Rails::VERSION::STRING
      self.logger = Rails.logger
      self.root_path = Rails.root.to_s
      self.view_paths = app.config.paths['app/views'].existent
    end

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
