# frozen_string_literal: true

require 'elastic_apm/version'
require 'elastic_apm/log'

# Core
require 'elastic_apm/agent'
require 'elastic_apm/config'
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
  def self.start(config = Config.new)
    Agent.start config
  end

  # Stops the ElasticAPM Agent
  def self.stop
    Agent.stop
  end

  # Returns whether the agent is currently running
  def self.running?
    Agent.running?
  end

  ### Metrics

  # Returns the currently active transaction (if any)
  def self.current_transaction
    agent&.current_transaction
  end

  def self.agent
    Agent.instance
  end

  def self.transaction(name, type = nil, result = nil, &block)
    agent.transaction name, type, result, &block
  end

  def self.trace(name, type = nil, extra = nil, &block)
    agent.trace name, type, extra, &block
  end
end
