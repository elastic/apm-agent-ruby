# frozen_string_literal: true

require 'elastic_apm/naively_hashable'
require 'elastic_apm/context_builder'
require 'elastic_apm/error_builder'
require 'elastic_apm/stacktrace_builder'
require 'elastic_apm/error'
require 'elastic_apm/transport/base'
require 'elastic_apm/spies'

module ElasticAPM
  # rubocop:disable Metrics/ClassLength
  # @api private
  class Agent
    include Log

    LOCK = Mutex.new

    # life cycle

    def self.instance # rubocop:disable Style/TrivialAccessors
      @instance
    end

    def self.start(config) # rubocop:disable Metrics/MethodLength
      return @instance if @instance

      config = Config.new(config) unless config.is_a?(Config)

      unless config.enabled_environments.include?(config.environment)
        unless config.disable_environment_warning?
          puts format(
            '%sNot tracking anything in "%s" env',
            Log::PREFIX, config.environment
          )
        end

        return
      end

      LOCK.synchronize do
        return @instance if @instance

        @instance = new(config).start
      end
    end

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
      @transport = Transport::Base.new(config)

      @instrumenter = Instrumenter.new(self)

      @context_builder = ContextBuilder.new(self)
      @error_builder = ErrorBuilder.new(self)
      @stacktrace_builder = StacktraceBuilder.new(self)
    end

    attr_reader :config, :transport, :messages, :pending_transactions,
      :instrumenter, :context_builder, :stacktrace_builder, :error_builder

    def start
      debug '[%s] Starting agent, reporting to %s', VERSION, config.server_url

      @instrumenter.start

      config.enabled_spies.each do |lib|
        require "elastic_apm/spies/#{lib}"
      end

      self
    end

    def stop
      @instrumenter.stop
      @transport.flush

      self
    end

    at_exit do
      stop
    end

    # transport

    def enqueue_transaction(transaction)
      @transport.submit transaction
    end

    def enqueue_span(span)
      @transport.submit span
    end

    def enqueue_error(error)
      @transport.submit error
    end

    def flush
      @transport.flush
    end

    # instrumentation

    def current_transaction
      instrumenter.current_transaction
    end

    def transaction(name = nil, type = nil, context: nil, sampled: nil, &block)
      instrumenter.transaction(
        name,
        type,
        context: context,
        sampled: sampled,
        &block
      )
    end

    def span(name, type = nil, backtrace: nil, context: nil, &block)
      instrumenter.span(
        name,
        type,
        backtrace: backtrace,
        context: context,
        &block
      )
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
      enqueue_error error
    end

    def report_message(message, backtrace: nil, **attrs)
      error = @error_builder.build_log(
        message,
        backtrace: backtrace,
        **attrs
      )
      enqueue_error error
    end

    # context

    def set_tag(key, value)
      instrumenter.set_tag(key, value)
    end

    def set_custom_context(context)
      instrumenter.set_custom_context(context)
    end

    def set_user(user)
      instrumenter.set_user(user)
    end

    def add_filter(key, callback)
      @transport.filters.add(key, callback)
    end

    def inspect
      '<ElasticAPM::Agent>'
    end
  end
  # rubocop:enable Metrics/ClassLength
end
