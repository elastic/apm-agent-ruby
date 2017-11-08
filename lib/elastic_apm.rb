# frozen_string_literal: true

require 'elastic_apm/version'
require 'elastic_apm/log'

require 'elastic_apm/agent'
require 'elastic_apm/config'
require 'elastic_apm/http'
require 'elastic_apm/injectors'
require 'elastic_apm/middleware'
require 'elastic_apm/normalizers'
require 'elastic_apm/serializers/transactions'
require 'elastic_apm/subscriber'
require 'elastic_apm/trace'
require 'elastic_apm/transaction'
require 'elastic_apm/util'
require 'elastic_apm/worker'

require 'elastic_apm/integration/railtie' if defined?(::Rails::Railtie)

# ElasticAPM
module ElasticAPM
  # Starts the ElasticAPM Agent
  #
  # @param config [Config] An instance of Config
  def self.start(options)
    Agent.start options
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

  def self.transaction(name, type = nil, result = nil, &block)
    agent.transaction name, type, result, &block
  end

  def self.trace(name, type = nil, extra = nil, &block)
    agent.trace name, type, extra, &block
  end
end
