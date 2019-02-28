# frozen_string_literal: true

require 'elastic_apm/context_builder'
require 'elastic_apm/error_builder'
require 'elastic_apm/stacktrace_builder'
require 'elastic_apm/error'
require 'elastic_apm/transport/base'
require 'elastic_apm/spies'
require 'elastic_apm/metrics'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Agent
    include Logging

    LOCK = Mutex.new

    # life cycle

    def self.instance # rubocop:disable Style/TrivialAccessors
      @instance
    end

    # rubocop:disable Metrics/MethodLength
    def self.start(config)
      return @instance if @instance

      config = Config.new(config) unless config.is_a?(Config)

      LOCK.synchronize do
        return @instance if @instance

        unless config.active?
          config.logger.debug format(
            '%sAgent disabled with active: false',
            Logging::PREFIX
          )
          return
        end

        @instance = new(config).start
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.stop
      LOCK.synchronize do
        return unless @instance

        @instance.stop
        @instance = nil
      end
    end

    def self.running?
      !!@instance
    end

    def initialize(config)
      @config = config

      @stacktrace_builder = StacktraceBuilder.new(config)
      @context_builder = ContextBuilder.new(config)
      @error_builder = ErrorBuilder.new(self)

      @transport = Transport::Base.new(config)
      @instrumenter = Instrumenter.new(
        config,
        stacktrace_builder: stacktrace_builder
      ) { |event| enqueue event }
      @metrics = Metrics.new(config) { |event| enqueue event }
    end

    attr_reader :config, :transport, :instrumenter,
      :stacktrace_builder, :context_builder, :error_builder, :metrics

    def start
      info '[%s] Starting agent, reporting to %s', VERSION, config.server_url

      transport.start
      instrumenter.start
      metrics.start

      config.enabled_spies.each do |lib|
        require "elastic_apm/spies/#{lib}"
      end

      self
    end

    def stop
      debug 'Stopping agent'

      instrumenter.stop
      transport.stop
      metrics.stop

      self
    end

    at_exit do
      stop
    end

    # transport

    def enqueue(obj)
      transport.submit obj
    end

    # instrumentation

    def current_transaction
      instrumenter.current_transaction
    end

    def current_span
      instrumenter.current_span
    end

    def start_transaction(
      name = nil,
      type = nil,
      context: nil,
      trace_context: nil
    )
      instrumenter.start_transaction(
        name,
        type,
        context: context,
        trace_context: trace_context
      )
    end

    def end_transaction(result = nil)
      instrumenter.end_transaction(result)
    end

    def start_span(
      name = nil,
      type = nil,
      backtrace: nil,
      context: nil,
      trace_context: nil
    )
      instrumenter.start_span(
        name,
        type,
        backtrace: backtrace,
        context: context,
        trace_context: trace_context
      )
    end

    def end_span
      instrumenter.end_span
    end

    def set_tag(key, value)
      instrumenter.set_tag(key, value)
    end

    def set_custom_context(context)
      instrumenter.set_custom_context(context)
    end

    def set_user(user)
      instrumenter.set_user(user)
    end

    def build_context(rack_env)
      @context_builder.build(rack_env)
    end

    # errors

    def report(exception, handled: true)
      return if config.filter_exception_types.include?(exception.class.to_s)

      error = @error_builder.build_exception(
        exception,
        handled: handled
      )
      enqueue error
    end

    def report_message(message, backtrace: nil, **attrs)
      error = @error_builder.build_log(
        message,
        backtrace: backtrace,
        **attrs
      )
      enqueue error
    end

    # filters

    def add_filter(key, callback)
      transport.add_filter(key, callback)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
