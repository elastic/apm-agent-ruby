# frozen_string_literal: true

require 'elastic_apm/version'

require 'elastic_apm/agent'
require 'elastic_apm/config'
require 'elastic_apm/middleware'
require 'elastic_apm/transaction'

# ElasticAPM
module ElasticAPM
  # Starts the ElasticAPM Agent
  #
  # @param config [Config] An instance of Config
  def self.start(config)
    Agent.start config
  end

  # Stops the ElasticAPM Agent
  def self.stop
    Agent.stop
  end

  def self.started?
    Agent.started?
  end

  def self.agent
    Agent.instance
  end

  def self.transaction(name, kind = nil, result = nil, &block)
    agent.transaction name, kind, result, &block
  end
end
