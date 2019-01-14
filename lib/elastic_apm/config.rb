# frozen_string_literal: true

require 'logger'
require 'yaml'

require 'elastic_apm/util/prefixed_logger'
require 'elastic_apm/config/duration'
require 'elastic_apm/config/size'

module ElasticAPM
  class ConfigError < StandardError; end

  # rubocop:disable Metrics/ClassLength
  # @api private
  class Config
    DEFAULTS = {
      config_file: 'config/elastic_apm.yml',

      server_url: 'http://localhost:8200',

      api_buffer_size: 256,
      api_request_size: '750kb',
      api_request_time: '10s',
      capture_body: true,
      capture_headers: true,
      capture_env: true,
      current_user_email_method: :email,
      current_user_id_method: :id,
      current_user_username_method: :username,
      custom_key_filters: [],
      default_tags: {},
      disable_send: false,
      disabled_spies: %w[json],
      environment: ENV['RAILS_ENV'] || ENV['RACK_ENV'],
      filter_exception_types: [],
      http_compression: true,
      ignore_url_patterns: [],
      instrument: true,
      instrumented_rake_tasks: [],
      log_level: Logger::INFO,
      log_path: nil,
      pool_size: 1,
      source_lines_error_app_frames: 5,
      source_lines_error_library_frames: 0,
      source_lines_span_app_frames: 5,
      source_lines_span_library_frames: 0,
      span_frames_min_duration: '5ms',
      transaction_max_spans: 500,
      transaction_sample_rate: 1.0,
      verify_server_cert: true,

      view_paths: [],
      root_path: Dir.pwd
    }.freeze

    ENV_TO_KEY = {
      'ELASTIC_APM_SERVER_URL' => 'server_url',
      'ELASTIC_APM_SECRET_TOKEN' => 'secret_token',

      'ELASTIC_APM_API_BUFFER_SIZE' => [:int, 'api_buffer_size'],
      'ELASTIC_APM_API_REQUEST_SIZE' => [:int, 'api_request_size'],
      'ELASTIC_APM_API_REQUEST_TIME' => 'api_request_time',
      'ELASTIC_APM_CAPTURE_BODY' => [:bool, 'capture_body'],
      'ELASTIC_APM_CAPTURE_HEADERS' => [:bool, 'capture_headers'],
      'ELASTIC_APM_CAPTURE_ENV' => [:bool, 'capture_env'],
      'ELASTIC_APM_CUSTOM_KEY_FILTERS' => [:list, 'custom_key_filters'],
      'ELASTIC_APM_DEFAULT_TAGS' => [:dict, 'default_tags'],
      'ELASTIC_APM_DISABLED_SPIES' => [:list, 'disabled_spies'],
      'ELASTIC_APM_DISABLE_SEND' => [:bool, 'disable_send'],
      'ELASTIC_APM_ENVIRONMENT' => 'environment',
      'ELASTIC_APM_FRAMEWORK_NAME' => 'framework_name',
      'ELASTIC_APM_FRAMEWORK_VERSION' => 'framework_version',
      'ELASTIC_APM_HOSTNAME' => 'hostname',
      'ELASTIC_APM_IGNORE_URL_PATTERNS' => [:list, 'ignore_url_patterns'],
      'ELASTIC_APM_INSTRUMENT' => [:bool, 'instrument'],
      'ELASTIC_APM_INSTRUMENTED_RAKE_TASKS' =>
        [:list, 'instrumented_rake_tasks'],
      'ELASTIC_APM_LOG_LEVEL' => [:int, 'log_level'],
      'ELASTIC_APM_LOG_PATH' => 'log_path',
      'ELASTIC_APM_POOL_SIZE' => [:int, 'pool_size'],
      'ELASTIC_APM_SERVICE_NAME' => 'service_name',
      'ELASTIC_APM_SERVICE_VERSION' => 'service_version',
      'ELASTIC_APM_SOURCE_LINES_ERROR_APP_FRAMES' =>
        [:int, 'source_lines_error_app_frames'],
      'ELASTIC_APM_SOURCE_LINES_ERROR_LIBRARY_FRAMES' =>
        [:int, 'source_lines_error_library_frames'],
      'ELASTIC_APM_SOURCE_LINES_SPAN_APP_FRAMES' =>
        [:int, 'source_lines_span_app_frames'],
      'ELASTIC_APM_SOURCE_LINES_SPAN_LIBRARY_FRAMES' =>
        [:int, 'source_lines_span_library_frames'],
      'ELASTIC_APM_SPAN_FRAMES_MIN_DURATION' => 'span_frames_min_duration',
      'ELASTIC_APM_TRANSACTION_MAX_SPANS' => [:int, 'transaction_max_spans'],
      'ELASTIC_APM_TRANSACTION_SAMPLE_RATE' =>
        [:float, 'transaction_sample_rate'],
      'ELASTIC_APM_VERIFY_SERVER_CERT' => [:bool, 'verify_server_cert']
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

      build_logger if logger.nil?
    end

    attr_accessor :config_file

    attr_accessor :server_url
    attr_accessor :secret_token

    attr_accessor :api_buffer_size
    attr_accessor :api_request_size
    attr_accessor :api_request_time
    attr_accessor :capture_body
    attr_accessor :capture_headers
    attr_accessor :capture_env
    attr_accessor :current_user_email_method
    attr_accessor :current_user_id_method
    attr_accessor :current_user_method
    attr_accessor :current_user_username_method
    attr_accessor :default_tags
    attr_accessor :disable_send
    attr_accessor :disabled_spies
    attr_accessor :environment
    attr_accessor :filter_exception_types
    attr_accessor :framework_name
    attr_accessor :framework_version
    attr_accessor :hostname
    attr_accessor :http_compression
    attr_accessor :instrument
    attr_accessor :instrumented_rake_tasks
    attr_accessor :log_level
    attr_accessor :log_path
    attr_accessor :logger
    attr_accessor :pool_size
    attr_accessor :service_name
    attr_accessor :service_version
    attr_accessor :source_lines_error_app_frames
    attr_accessor :source_lines_error_library_frames
    attr_accessor :source_lines_span_app_frames
    attr_accessor :source_lines_span_library_frames
    attr_accessor :transaction_max_spans
    attr_accessor :transaction_sample_rate
    attr_accessor :verify_server_cert

    attr_reader :custom_key_filters
    attr_reader :ignore_url_patterns
    attr_reader :span_frames_min_duration
    attr_reader :span_frames_min_duration_us

    attr_accessor :view_paths
    attr_accessor :root_path

    alias :capture_body? :capture_body
    alias :capture_headers? :capture_headers
    alias :capture_env? :capture_env
    alias :disable_send? :disable_send
    alias :http_compression? :http_compression
    alias :instrument? :instrument
    alias :verify_server_cert? :verify_server_cert

    def alert_logger
      @alert_logger ||= PrefixedLogger.new($stdout, prefix: Logging::PREFIX)
    end

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
        faraday
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

    def span_frames_min_duration?
      span_frames_min_duration != 0
    end

    DEPRECATED_OPTIONS = %i[
      compression_level=
      compression_minimum_size=
      debug_http=
      debug_transactions=
      flush_interval=
      http_open_timeout=
      http_read_timeout=
      enabled_environments=
      disable_environment_warning=
    ].freeze

    def respond_to_missing?(name)
      return true if DEPRECATED_OPTIONS.include? name
      return true if name.to_s.end_with?('=')
      false
    end

    def method_missing(name, *args)
      if DEPRECATED_OPTIONS.include?(name)
        alert_logger.warn "The option `#{name}' has been removed."
        return
      end

      if name.to_s.end_with?('=')
        raise ConfigError, "No such option `#{name.to_s.delete('=')}'"
      end

      super
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
    rescue ConfigError => e
      alert_logger.warn format(
        'Failed to configure from arguments: %s',
        e.message
      )
    end

    def set_from_config_file
      return unless File.exist?(config_file)
      assign(YAML.load_file(config_file) || {})
    rescue ConfigError => e
      alert_logger.warn format(
        'Failed to configure from config file: %s',
        e.message
      )
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
      logger = Logger.new(log_path == '-' ? STDOUT : log_path)
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
