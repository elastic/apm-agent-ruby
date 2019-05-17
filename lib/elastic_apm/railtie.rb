# frozen_string_literal: true

require 'elastic_apm/subscriber'

module ElasticAPM
  # @api private
  class Railtie < Rails::Railtie
    config.elastic_apm = ActiveSupport::OrderedOptions.new

    Config::DEFAULTS.each { |option, value| config.elastic_apm[option] = value }

    initializer 'elastic_apm.initialize' do |app|
      config = Config.new(app.config.elastic_apm.merge(app: app)).tap do |c|
        # Prepend Rails.root to log_path if present
        if c.log_path && !c.log_path.start_with?('/')
          c.log_path = Rails.root.join(c.log_path)
        end
      end

      if start(config)
        app.middleware.insert 0, Middleware
      end
    end

    config.after_initialize do
      if ElasticAPM.running? &&
         !ElasticAPM.agent.config.disabled_spies.include?('action_dispatch')
        require 'elastic_apm/spies/action_dispatch'
      end
    end

    private

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def start(config)
      if (reason = should_skip?(config))
        unless config.disable_start_message?
          config.alert_logger.info "Skipping because: #{reason}. " \
            "Start manually with `ElasticAPM.start'"
        end
        return
      end

      ElasticAPM.start(config).tap do |agent|
        attach_subscriber(agent)
      end
    rescue StandardError => e
      config.alert_logger.error format('Failed to start: %s', e.message)
      config.alert_logger.debug "Backtrace:\n" + e.backtrace.join("\n")
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def should_skip?(_config)
      if Rails.const_defined? 'Rails::Console'
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
