# frozen_string_literal: true

require 'logger'
require 'yaml'
require 'erb'

require 'elastic_apm/util/prefixed_logger'

require 'elastic_apm/config/options'
require 'elastic_apm/config/duration'
require 'elastic_apm/config/bytes'
require 'elastic_apm/config/regexp_list'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Config
    extend Options

    DEPRECATED_OPTIONS = %i[].freeze

    # rubocop:disable Metrics/LineLength, Layout/ExtraSpacing
    option :config_file,                       type: :string, default: 'config/elastic_apm.yml'
    option :server_url,                        type: :string, default: 'http://localhost:8200'
    option :secret_token,                      type: :string

    option :active,                            type: :bool,   default: true
    option :api_buffer_size,                   type: :int,    default: 256
    option :api_request_size,                  type: :bytes,  default: '750kb', converter: Bytes.new
    option :api_request_time,                  type: :float,  default: '10s',   converter: Duration.new
    option :capture_body,                      type: :string, default: 'off'
    option :capture_headers,                   type: :bool,   default: true
    option :capture_env,                       type: :bool,   default: true
    option :central_config,                    type: :bool,   default: true
    option :current_user_email_method,         type: :string, default: 'email'
    option :current_user_id_method,            type: :string, default: 'id'
    option :current_user_username_method,      type: :string, default: 'username'
    option :custom_key_filters,                type: :list,   default: [],      converter: RegexpList.new
    option :default_tags,                      type: :dict,   default: {}
    option :default_labels,                    type: :dict,   default: {}
    option :disable_send,                      type: :bool,   default: false
    option :disable_start_message,             type: :bool,   default: false
    option :disabled_instrumentations,         type: :list,   default: %w[json]
    option :disabled_spies,                    type: :list,   default: []
    option :environment,                       type: :string, default: ENV['RAILS_ENV'] || ENV['RACK_ENV']
    option :framework_name,                    type: :string
    option :framework_version,                 type: :string
    option :filter_exception_types,            type: :list,   default: []
    option :global_labels,                     type: :dict
    option :hostname,                          type: :string
    option :http_compression,                  type: :bool,   default: true
    option :ignore_url_patterns,               type: :list,   default: [],      converter: RegexpList.new
    option :instrument,                        type: :bool,   default: true
    option :instrumented_rake_tasks,           type: :list,   default: []
    option :log_level,                         type: :int,    default: Logger::INFO
    option :log_path,                          type: :string
    option :metrics_interval,                  type: :int,    default: '30s',   converter: Duration.new
    option :pool_size,                         type: :int,    default: 1
    option :proxy_address,                     type: :string
    option :proxy_headers,                     type: :dict
    option :proxy_password,                    type: :string
    option :proxy_port,                        type: :int
    option :proxy_username,                    type: :string
    option :server_ca_cert,                    type: :string
    option :service_name,                      type: :string
    option :service_version,                   type: :string
    option :source_lines_error_app_frames,     type: :int,    default: 5
    option :source_lines_error_library_frames, type: :int,    default: 0
    option :source_lines_span_app_frames,      type: :int,    default: 5
    option :source_lines_span_library_frames,  type: :int,    default: 0
    option :span_frames_min_duration,          type: :float,  default: '5ms',   converter: Duration.new(default_unit: 'ms')
    option :stack_trace_limit,                 type: :int,    default: 999_999
    option :transaction_max_spans,             type: :int,    default: 500
    option :transaction_sample_rate,           type: :float,  default: 1.0
    option :verify_server_cert,                type: :bool,   default: true
    # rubocop:enable Metrics/LineLength, Layout/ExtraSpacing

    # rubocop:disable Metrics/MethodLength
    def initialize(options = {})
      @options = load_schema

      custom_logger = options.delete(:logger)

      assign(options)

      # Pick out config_file specifically as we need it now to load it,
      # but still need the other env vars to have precedence
      env = load_env
      if (env_config_file = env.delete(:config_file))
        self.config_file = env_config_file
      end

      assign(load_config_file)
      assign(env)

      yield self if block_given?

      @logger = custom_logger || build_logger

      @__view_paths = []
      @__root_path = Dir.pwd
    end
    # rubocop:enable Metrics/MethodLength

    attr_accessor :__view_paths, :__root_path
    attr_accessor :logger

    attr_reader :options

    def assign(update)
      return unless update
      update.each { |key, value| send(:"#{key}=", value) }
    end

    # rubocop:disable Metrics/MethodLength
    def available_instrumentations
      %w[
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

    def enabled_instrumentations
      available_instrumentations - disabled_instrumentations
    end

    def method_missing(name, *args)
      return super unless DEPRECATED_OPTIONS.include?(name)
      warn "The option `#{name}' has been removed."
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

    def use_ssl?
      server_url.start_with?('https')
    end

    def collect_metrics?
      metrics_interval > 0
    end

    def span_frames_min_duration?
      span_frames_min_duration != 0
    end

    def span_frames_min_duration=(value)
      super
      @span_frames_min_duration_us = nil
    end

    def span_frames_min_duration_us
      @span_frames_min_duration_us ||= span_frames_min_duration * 1_000_000
    end

    def inspect
      super.split.first + '>'
    end

    private

    def load_config_file
      return unless File.exist?(config_file)

      read = File.read(config_file)
      evaled = ERB.new(read).result
      YAML.safe_load(evaled)
    end

    def load_env
      @options.values.each_with_object({}) do |option, opts|
        next unless (value = ENV[option.env_key])
        opts[option.key] = value
      end
    end

    def build_logger
      Logger.new(log_path == '-' ? STDOUT : log_path).tap do |logger|
        logger.level = log_level
      end
    end

    def app_type?(app)
      if defined?(::Rails::Application) && app.is_a?(::Rails::Application)
        return :rails
      end

      if app.is_a?(Class) && app.superclass.to_s == 'Sinatra::Base'
        return :sinatra
      end

      nil
    end

    def set_sinatra(app)
      self.service_name = format_name(service_name || app.to_s)
      self.framework_name = framework_name || 'Sinatra'
      self.framework_version = framework_version || ::Sinatra::VERSION
      self.__root_path = Dir.pwd
    end

    def set_rails(app) # rubocop:disable Metrics/AbcSize
      self.service_name ||= format_name(service_name || rails_app_name(app))
      self.framework_name ||= 'Ruby on Rails'
      self.framework_version ||= ::Rails::VERSION::STRING
      self.logger ||= ::Rails.logger

      self.__root_path = ::Rails.root.to_s
      self.__view_paths = app.config.paths['app/views'].existent
    end

    def rails_app_name(app)
      if ::Rails::VERSION::MAJOR >= 6
        app.class.module_parent_name
      else
        app.class.parent_name
      end
    end

    def format_name(str)
      str && str.gsub('::', '_')
    end
  end
  # rubocop:enable Metrics/ClassLength
end
