# frozen_string_literal: true

require 'elastic_apm/version'
require 'elastic_apm/log'

# Core
require 'elastic_apm/naively_hashable'
require 'elastic_apm/agent'
require 'elastic_apm/config'
require 'elastic_apm/context'
require 'elastic_apm/instrumenter'
require 'elastic_apm/internal_error'
require 'elastic_apm/util'

# Metrics
require 'elastic_apm/middleware'

require 'elastic_apm/railtie' if defined?(::Rails::Railtie)

# ElasticAPM
module ElasticAPM
  ### Life cycle

  # Starts the ElasticAPM Agent
  #
  # @param config [Config] An instance of Config
  # @return [Agent] The resulting [Agent]
  def self.start(config = {})
    Agent.start config
  end

  # Stops the ElasticAPM Agent
  def self.stop
    Agent.stop
  end

  # @return [Boolean] Whether there's an [Agent] running
  def self.running?
    Agent.running?
  end

  # @return [Agent] Currently running [Agent] if any
  def self.agent
    Agent.instance
  end

  ### Metrics

  # Returns the currently active transaction (if any)
  #
  # @return [Transaction] if any
  def self.current_transaction
    agent && agent.current_transaction
  end

  # Start a new transaction or return the currently running
  #
  # @param name [String] A description of the transaction, eg
  # `ExamplesController#index`
  # @param type [String] The kind of the transaction, eg `app.request.get` or
  # `db.mysql2.query`
  # @param context [Context] An optional APM Context env
  # @yield [Transaction] Optional block encapsulating transaction
  # @return [Transaction] Unless block given
  def self.transaction(name, type = nil, context: nil, &block)
    return call_through(&block) unless agent
    agent.transaction(name, type, context: context, &block)
  end

  # Starts a new span under the current Transaction
  #
  # @param name [String] A description of the span, eq `SELECT FROM "users"`
  # @param type [String] The kind of span, eq `db.mysql2.query`
  # @param context [Span::Context] Context information about the span
  # @yield [Span] Optional block encapsulating span
  # @return [Span] Unless block given
  def self.span(name, type = nil, context: nil, &block)
    return call_through(&block) unless agent
    agent.span(name, type, context: context, &block)
  end

  ### Errors

  # Report and exception to APM
  #
  # @param exception [Exception] The exception
  # @param handled [Boolean] Whether the exception was rescued
  # @return [Error] The generated [Error]
  def self.report(exception, handled: true)
    agent && agent.report(exception, handled: handled)
  end

  # Report a custom string error message to APM
  #
  # @param message [String] The message
  # @return [Error] The generated [Error]
  def self.report_message(message, **attrs)
    agent && agent.report_message(message, backtrace: caller, **attrs)
  end

  def self.build_context(rack_env)
    agent && agent.build_context(rack_env)
  end

  ### Context

  def self.set_tag(key, value)
    agent && agent.set_tag(key, value)
  end

  def self.set_custom_context(custom)
    agent && agent.set_custom_context(custom)
  end

  class << self
    private

    def call_through
      unless agent
        return yield if block_given?
      end

      nil
    end
  end
end
