# frozen_string_literal: true

require 'elastic_apm/version'
require 'elastic_apm/log'

# Core
require 'elastic_apm/agent'
require 'elastic_apm/config'
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
  def self.start(config = Config.new)
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
    agent&.current_transaction
  end

  # Start a new transaction or return the currently running
  #
  # @param name [String] A description of the transaction, eg
  # `ExamplesController#index`
  # @param type [String] The kind of the transaction, eg `app.request.get` or
  # `db.mysql2.query`
  # @param result [Object] Result of the transaction, eq `200` for a HTTP server
  # @yield [Transaction] Optional block encapsulating transaction
  # @return [Transaction] Unless block given
  def self.transaction(name, type = nil, result = nil, &block)
    agent&.transaction name, type, result, &block
  end

  # Starts a new span under the current Transaction
  #
  # @param name [String] A description of the span, eq `SELECT FROM "users"`
  # @param type [String] The kind of span, eq `db.mysql2.query`
  # @param extra [Hash] Extra information about the span
  # @yield [Span] Optional block encapsulating span
  # @return [Span] Unless block given
  def self.span(name, type = nil, extra = nil, &block)
    agent&.span name, type, extra, &block
  end

  ### Errors

  # Report and exception to APM
  #
  # @param exception [Exception] The exception
  # @param rack_env [Rack::Env] An optional Rack env
  # @param handled [Boolean] Whether the exception was rescued
  # @return [Error] An [Error] instance
  def self.report(exception, rack_env: nil, handled: true)
    agent&.report(exception, rack_env: rack_env, handled: handled)
  end
end
