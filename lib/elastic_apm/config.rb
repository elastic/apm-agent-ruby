# frozen_string_literal: true

require 'logger'
require 'yaml'

require 'elastic_apm/config/duration'
require 'elastic_apm/config/size'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Config
    DEFAULTS = {
      config_file: 'config/elastic_apm.yml',
      server_url: 'http://localhost:8200',

      environment: ENV['RAILS_ENV'] || ENV['RACK_ENV'],
      enabled_environments: %w[production],
      disable_environment_warning: false,
      instrument: true,

      log_path: nil,
      log_level: Logger::INFO,

      transaction_sample_rate: 1.0,
      transaction_max_spans: 500,
      filter_exception_types: [],

      # intake v2
      api_request_size: '750kb',
      api_request_time: '10s',
      api_buffer_size: 10,

      disable_send: false,
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
      span_frames_min_duration: '5ms',

      disabled_spies: %w[json],
      instrumented_rake_tasks: [],

      default_tags: {},

      current_user_id_method: :id,
      current_user_email_method: :email,
      current_user_username_method: :username,

      custom_key_filters: [],
      ignore_url_patterns: [],

      view_paths: [],
      root_path: Dir.pwd
    }.freeze

    ENV_TO_KEY = {
      'ELASTIC_APM_SERVER_URL' => 'server_url',
      'ELASTIC_APM_SECRET_TOKEN' => 'secret_token',

      'ELASTIC_APM_ENVIRONMENT' => 'environment',
      'ELASTIC_APM_ENABLED_ENVIRONMENTS' => [:list, 'enabled_environments'],
      'ELASTIC_APM_DISABLE_ENVIRONMENT_WARNING' =>
        [:bool, 'disable_environment_warning'],
      'ELASTIC_APM_INSTRUMENT' => [:bool, 'instrument'],

      'ELASTIC_APM_LOG_PATH' => 'log_path',
      'ELASTIC_APM_LOG_LEVEL' => [:int, 'log_level'],

      'ELASTIC_APM_SERVICE_NAME' => 'service_name',
      'ELASTIC_APM_SERVICE_VERSION' => 'service_version',
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
      'ELASTIC_APM_SPAN_FRAMES_MIN_DURATION' => 'span_frames_min_duration',

      'ELASTIC_APM_CUSTOM_KEY_FILTERS' => [:list, 'custom_key_filters'],
      'ELASTIC_APM_IGNORE_URL_PATTERNS' => [:list, 'ignore_url_patterns'],

      'ELASTIC_APM_API_REQUEST_SIZE' => [:int, 'api_request_size'],
      'ELASTIC_APM_API_REQUEST_TIME' => 'api_request_time',
      'ELASTIC_APM_API_BUFFER_SIZE' => [:int, 'api_buffer_size'],

      'ELASTIC_APM_TRANSACTION_SAMPLE_RATE' =>
        [:float, 'transaction_sample_rate'],
      'ELASTIC_APM_VERIFY_SERVER_CERT' => [:bool, 'verify_server_cert'],
      'ELASTIC_APM_TRANSACTION_MAX_SPANS' => [:int, 'transaction_max_spans'],

      'ELASTIC_APM_DISABLE_SEND' => [:bool, 'disable_send'],
      'ELASTIC_APM_DISABLED_SPIES' => [:list, 'disabled_spies'],
      'ELASTIC_APM_INSTRUMENTED_RAKE_TASKS' =>
        [:list, 'instrumented_rake_tasks'],

      'ELASTIC_APM_DEFAULT_TAGS' => [:dict, 'default_tags']
    }.freeze

    DURATION_KEYS = %i[api_request_time span_frames_min_duration].freeze
    DURATION_DEFAULT_UNITS = { span_frames_min_duration: 'ms' }.freeze

    SIZE_KEYS = %i[api_request_size].freeze
    SIZE_DEFAULT_UNITS = { api_request_size: 'kb' }.freeze

    def initialize(options = {})
      set_defaults

      set_from_args(options)
      set_from_config_file
      set_from_env

      normalize_durations
      normalize_sizes

      yield self if block_given?

      build_logger if logger.nil? || log_path
    end

    attr_accessor :config_file

    attr_accessor :server_url
    attr_accessor :secret_token

    attr_accessor :environment
    attr_accessor :enabled_environments
    attr_accessor :disable_environment_warning
    attr_accessor :instrument

    attr_accessor :service_name
    attr_accessor :service_version
    attr_accessor :framework_name
    attr_accessor :framework_version
    attr_accessor :hostname

    attr_accessor :log_path
    attr_accessor :log_level
    attr_accessor :logger

    attr_accessor :api_request_size
    attr_accessor :api_request_time
    attr_accessor :api_buffer_size

    attr_accessor :transaction_sample_rate
    attr_accessor :transaction_max_spans
    attr_accessor :verify_server_cert
    attr_accessor :filter_exception_types

    attr_accessor :disable_send
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

    attr_reader :span_frames_min_duration
    attr_reader :span_frames_min_duration_us

    attr_accessor :disabled_spies
    attr_accessor :instrumented_rake_tasks

    attr_accessor :view_paths
    attr_accessor :root_path

    attr_accessor :current_user_method
    attr_accessor :current_user_id_method
    attr_accessor :current_user_email_method
    attr_accessor :current_user_username_method

    attr_accessor :default_tags

    attr_reader   :custom_key_filters
    attr_reader   :ignore_url_patterns

    alias :debug_transactions? :debug_transactions
    alias :disable_environment_warning? :disable_environment_warning
    alias :disable_send? :disable_send
    alias :http_compression? :http_compression
    alias :instrument? :instrument
    alias :verify_server_cert? :verify_server_cert

    def app=(app)
      case app_type?(app)
      when :sinatra
        set_sinatra(app)
      when :rails
        set_rails(app)
      else
        self.service_name = 'ruby'
      end
    end

    def app_type?(app)
      if defined?(Rails::Application) && app.is_a?(Rails::Application)
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

    def custom_key_filters=(filters)
      @custom_key_filters = Array(filters).map(&Regexp.method(:new))
    end

    def ignore_url_patterns=(strings)
      @ignore_url_patterns = Array(strings).map(&Regexp.method(:new))
    end

    # rubocop:disable Metrics/MethodLength
    def available_spies
      %w[
        action_dispatch
        delayed_job
        elasticsearch
        http
        json
        mongo
        net_http
        redis
        sequel
        sidekiq
        sinatra
        tilt
        rake
      ]
    end
    # rubocop:enable Metrics/MethodLength

    def enabled_spies
      available_spies - disabled_spies
    end

    def span_frames_min_duration=(duration)
      @span_frames_min_duration = duration
      @span_frames_min_duration_us = duration * 1_000_000
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
    # rubocop:disable Metrics/AbcSize
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
          when :dict then Hash[value.split('&').map { |kv| kv.split('=') }]
          else value
          end

        send("#{key}=", value)
      end
    end
    # rubocop:enable Metrics/AbcSize
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

    def build_logger
      logger = Logger.new(log_path == '-' ? $stdout : log_path)
      logger.level = log_level

      self.logger = logger
    end

    def format_name(str)
      str.gsub('::', '_')
    end

    def normalize_durations
      DURATION_KEYS.each do |key|
        value = send(key).to_s
        default_unit = DURATION_DEFAULT_UNITS.fetch(key, 's')
        duration = Duration.parse(value, default_unit: default_unit)
        send("#{key}=", duration.seconds)
      end
    end

    def normalize_sizes
      SIZE_KEYS.each do |key|
        value = send(key).to_s
        default_unit = SIZE_DEFAULT_UNITS.fetch(key, 'b')
        size = Size.parse(value, default_unit: default_unit)
        send("#{key}=", size.bytes)
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
