# frozen_string_literal: true

require 'elastic_apm/version'
require 'elastic_apm/internal_error'
require 'elastic_apm/logging'
require 'elastic_apm/deprecations'

# Core
require 'elastic_apm/agent'
require 'elastic_apm/config'
require 'elastic_apm/context'
require 'elastic_apm/instrumenter'
require 'elastic_apm/util'

require 'elastic_apm/middleware'

require 'elastic_apm/railtie' if defined?(::Rails::Railtie)

# ElasticAPM
module ElasticAPM
  class << self
    extend ElasticAPM::Deprecations

    ### Life cycle

    # Starts the ElasticAPM Agent
    #
    # @param config [Config] An instance of Config
    # @return [Agent] The resulting [Agent]
    def start(config = {})
      Agent.start config
    end

    # Stops the ElasticAPM Agent
    def stop
      Agent.stop
    end

    # @return [Boolean] Whether there's an [Agent] running
    def running?
      Agent.running?
    end

    # @return [Agent] Currently running [Agent] if any
    def agent
      Agent.instance
    end

    ### Metrics
    # Returns the currently active transaction (if any)
    #
    # @return [Transaction] if any
    def current_transaction
      agent && agent.current_transaction
    end

    # Start a new transaction or return the currently running
    #
    # @param name [String] A description of the transaction, eg
    # `ExamplesController#index`
    # @param type [String] The kind of the transaction, eg `app.request.get` or
    # `db.mysql2.query`
    # @param context [Context] An optional [Context]
    # @yield [Transaction] Optional block encapsulating transaction
    # @return [Transaction] Unless block given
    # @deprecated See `with_transaction` or `start_transaction`
    def transaction(name = nil, type = nil, context: nil, &block)
      return (block_given? ? yield : nil) unless agent
      agent.transaction(name, type, context: context, &block)
    end

    deprecate :transaction, :with_transaction

    def start_transaction(name = nil, type = nil, context: nil)
      agent&.start_transaction(name, type, context: context)
    end

    def end_transaction(result = nil)
      agent&.end_transaction(result)
    end

    def submit_transaction(result = nil)
      agent&.submit_transaction(result)
    end

    # rubocop:disable Metrics/MethodLength
    def with_transaction(name = nil, type = nil, context: nil)
      unless block_given?
        raise ArgumentError,
          'expected a block. Do you want `start_transaction\' instead?'
      end

      return yield(nil) unless agent

      begin
        transaction = start_transaction(name, type, context: context)
        yield transaction
      ensure
        end_transaction
      end
    end
    # rubocop:enable Metrics/MethodLength

    def flush
      agent&.flush
    end

    # Starts a new span under the current Transaction
    #
    # @param name [String] A description of the span, eq `SELECT FROM "users"`
    # @param type [String] The kind of span, eq `db.mysql2.query`
    # @param context [Span::Context] Context information about the span
    # @yield [Span] Optional block encapsulating span
    # @return [Span] Unless block given
    def span(name, type = nil, context: nil, include_stacktrace: true, &block)
      return (block_given? ? yield : nil) unless agent

      agent.span(
        name,
        type,
        context: context,
        backtrace: include_stacktrace ? caller : nil,
        &block
      )
    end

    # Build a [Context] from a Rack `env`. The context may include information
    # about the request, response, current user and more
    #
    # @param rack_env [Rack::Env] A Rack env
    # @return [Context] The built context
    def build_context(rack_env)
      agent && agent.build_context(rack_env)
    end

    ### Errors

    # Report and exception to APM
    #
    # @param exception [Exception] The exception
    # @param handled [Boolean] Whether the exception was rescued
    # @return [Error] The generated [Error]
    def report(exception, handled: true)
      agent && agent.report(exception, handled: handled)
    end

    # Report a custom string error message to APM
    #
    # @param message [String] The message
    # @return [Error] The generated [Error]
    def report_message(message, **attrs)
      agent && agent.report_message(message, backtrace: caller, **attrs)
    end

    ### Context

    # Set a _tag_ value for the current transaction
    #
    # @param key [String,Symbol] A key
    # @param value [Object] A value (will be converted to string)
    # @return [Object] The given value
    def set_tag(key, value)
      agent && agent.set_tag(key, value)
    end

    # Provide further context for the current transaction
    #
    # @param custom [Hash] A hash with custom information. Can be nested.
    # @return [Hash] The current custom context
    def set_custom_context(custom)
      agent && agent.set_custom_context(custom)
    end

    # Provide a user to the current transaction
    #
    # @param user [Object] An object representing a user
    # @return [Object] Given user
    def set_user(user)
      agent && agent.set_user(user)
    end

    # Provide a filter to transform payloads before sending them off
    #
    # @param key [Symbol] Unique filter key
    # @param callback [Object, Proc] A filter that responds to #call(payload)
    # @yield [Hash] A filter. Used if provided. Otherwise using `callback`
    # @return [Bool] true
    def add_filter(key, callback = nil, &block)
      if callback.nil? && !block_given?
        raise ArgumentError, '#add_filter needs either `callback\' or a block'
      end

      agent && agent.add_filter(key, block || callback)
    end
  end
end
