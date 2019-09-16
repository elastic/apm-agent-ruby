# frozen_string_literal: true

require 'elastic_apm/subscriber'

module ElasticAPM
  # @api private
  module Rails
    extend self
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
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
         !ElasticAPM.agent.config.disabled_spies.include?('action_dispatch')
        require 'elastic_apm/spies/action_dispatch'
      end
      ElasticAPM.running?
    rescue StandardError => e
      config.logger.error format('Failed to start: %s', e.message)
      config.logger.debug "Backtrace:\n" + e.backtrace.join("\n")
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
