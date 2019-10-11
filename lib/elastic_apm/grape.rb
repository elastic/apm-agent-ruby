# frozen_string_literal: true

require 'elastic_apm/subscriber'
require 'elastic_apm/normalizers/grape'

module ElasticAPM
  module Grape
    extend self
    # Start the ElasticAPM agent and hook into Grape.
    #
    # @param config [Config, Hash] An instance of Config or a Hash config.
    # @return [true, nil] true if the agent was started, nil otherwise.
    def start(config)
      config = Config.new(config) unless config.is_a?(Config)
      ElasticAPM.start(config).tap do |agent|
        attach_subscriber(agent)
      end
      ElasticAPM.running?
    rescue StandardError => e
      config.logger.error format('Failed to start: %s', e.message)
      config.logger.debug "Backtrace:\n" + e.backtrace.join("\n")
    end

    private

    def attach_subscriber(agent)
      return unless agent

      agent.instrumenter.subscriber = ElasticAPM::Subscriber.new(agent)
    end
  end
end
