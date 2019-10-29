# frozen_string_literal: true

require 'elastic_apm/railtie'
require 'elastic_apm/subscriber'
require 'elastic_apm/normalizers/rails'

module ElasticAPM
  # Module for explicitly starting the ElasticAPM agent and hooking into Rails.
  # It is recommended to use the Railtie instead.
  module Rails
    extend self

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # Start the ElasticAPM agent and hook into Rails.
    # Note that the agent won't be started if the Rails console is being used.
    #
    # @param config [Config, Hash] An instance of Config or a Hash config.
    # @return [true, nil] true if the agent was started, nil otherwise.
    def start(config)
      config = Config.new(config) unless config.is_a?(Config)

      if (reason = should_skip?(config))
        unless config.disable_start_message?
          config.logger.info "Skipping because: #{reason}. " \
            "Start manually with `ElasticAPM.start'"
        end

        return
      end

      ElasticAPM.start(config).tap do |agent|
        attach_subscriber(agent)
      end

      if ElasticAPM.running? &&
         !ElasticAPM.agent.config.disabled_instrumentations.include?(
           'action_dispatch'
         )
        require 'elastic_apm/spies/action_dispatch'
      end

      ElasticAPM.running?
    rescue StandardError => e
      if config.disable_start_message?
        config.logger.error format('Failed to start: %s', e.message)
        config.logger.debug "Backtrace:\n" + e.backtrace.join("\n")
      else
        puts format('Failed to start: %s', e.message)
        puts "Backtrace:\n" + e.backtrace.join("\n")
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def should_skip?(_config)
      if ::Rails.const_defined? 'Rails::Console'
        return 'Rails console'
      end

      nil
    end

    def attach_subscriber(agent)
      return unless agent

      agent.instrumenter.subscriber = ElasticAPM::Subscriber.new(agent)
    end
  end
end
