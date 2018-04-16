# frozen_string_literal: true

require 'logger'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Config
    DEFAULTS = {
      config_file: 'config/elastic_apm.yml',

      server_url: 'http://localhost:8200',
      secret_token: nil,

      service_name: nil,
      service_version: nil,
      environment: ENV['RAILS_ENV'] || ENV['RACK_ENV'],
      enabled_environments: %w[production],
      framework_name: nil,
      framework_version: nil,
      hostname: nil,

      log_path: '-',
      log_level: Logger::INFO,
      logger: nil,

      max_queue_size: 500,
      flush_interval: 10,
      transaction_sample_rate: 1.0,
      transaction_max_spans: 500,
      filter_exception_types: [],

      http_read_timeout: 120,
      http_open_timeout: 60,
      debug_transactions: false,
      debug_http: false,
      verify_server_cert: true,
      http_compression: true,
      compression_minimum_size: 1024 * 5,
      compression_level: 6,

      source_lines_error_app_frames: 5,
      source_lines_span_app_frames: 5,
      source_lines_error_library_frames: 0,
      source_lines_span_library_frames: 0,

      disabled_injectors: %w[json],

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
      'ELASTIC_APM_ENABLED_ENVIRONMENTS' => [:list, 'enabled_environments'],
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
        [:float, 'transaction_sample_rate'],
      'ELASTIC_APM_VERIFY_SERVER_CERT' => [:bool, 'verify_server_cert'],
      'ELASTIC_APM_TRANSACTION_MAX_SPANS' => [:int, 'transaction_max_spans'],

      'ELASTIC_APM_DISABLED_INJECTORS' => [:list, 'disabled_injectors']
    }.freeze

    def initialize(options = {})
      set_defaults

      set_from_args(options)
      set_from_config_file
      set_from_env

      yield self if block_given?
    end

    attr_accessor :config_file

    attr_accessor :server_url
    attr_accessor :secret_token

    attr_accessor :service_name
    attr_accessor :service_version
    attr_accessor :environment
    attr_accessor :framework_name
    attr_accessor :framework_version
    attr_accessor :hostname
    attr_accessor :enabled_environments

    attr_accessor :log_path
    attr_accessor :log_level

    attr_accessor :max_queue_size
    attr_accessor :flush_interval
    attr_accessor :transaction_sample_rate
    attr_accessor :transaction_max_spans
    attr_accessor :verify_server_cert
    attr_accessor :filter_exception_types

    attr_accessor :http_read_timeout
    attr_accessor :http_open_timeout
    attr_accessor :debug_transactions
    attr_accessor :debug_http
    attr_accessor :http_compression
    attr_accessor :compression_minimum_size
    attr_accessor :compression_level

    attr_accessor :source_lines_error_app_frames
    attr_accessor :source_lines_span_app_frames
    attr_accessor :source_lines_error_library_frames
    attr_accessor :source_lines_span_library_frames

    attr_accessor :disabled_injectors

    attr_accessor :view_paths
    attr_accessor :root_path

    attr_accessor :current_user_method
    attr_accessor :current_user_id_method
    attr_accessor :current_user_email_method
    attr_accessor :current_user_username_method

    attr_reader   :logger

    alias :verify_server_cert? :verify_server_cert

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

    # rubocop:disable Metrics/MethodLength
    def available_injectors
      %w[
        action_dispatch
        delayed_job
        elasticsearch
        json
        mongo
        net_http
        redis
        sequel
        sidekiq
        sinatra
        tilt
      ]
    end
    # rubocop:enable Metrics/MethodLength

    def enabled_injectors
      available_injectors - disabled_injectors
    end

    private

    def assign(options)
      options.each do |key, value|
        send("#{key}=", value)
      end
    end

    def set_defaults
      assign(DEFAULTS)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def set_from_env
      ENV_TO_KEY.each do |env_key, key|
        next unless (value = ENV[env_key])

        type, key = key if key.is_a? Array

        value =
          case type
          when :int then value.to_i
          when :float then value.to_f
          when :bool then !%w[0 false].include?(value.strip.downcase)
          when :list then value.split(/[ ,]/)
          else value
          end

        send("#{key}=", value)
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    def set_from_args(options)
      assign(options)
    end

    def set_from_config_file
      return unless File.exist?(config_file)
      assign(YAML.load_file(config_file) || {})
    end

    def set_sinatra(app)
      self.service_name = format_name(service_name || app.to_s)
      self.framework_name = framework_name || 'Sinatra'
      self.framework_version = framework_version || Sinatra::VERSION
      self.root_path = Dir.pwd
    end

    def set_rails(app) # rubocop:disable Metrics/AbcSize
      self.service_name ||= format_name(service_name || app.class.parent_name)
      self.framework_name ||= 'Ruby on Rails'
      self.framework_version ||= Rails::VERSION::STRING
      self.logger ||= Rails.logger

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
