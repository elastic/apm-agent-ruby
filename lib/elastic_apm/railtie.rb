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

      begin
        agent = ElasticAPM.start config

        if agent
          agent.instrumenter.subscriber = ElasticAPM::Subscriber.new(agent)

          app.middleware.insert 0, Middleware
        end
      rescue StandardError => e
        config.alert_logger.error format('Failed to start: %s', e.message)
        config.alert_logger.debug "Backtrace:\n" + e.backtrace.join("\n")
      end
    end

    config.after_initialize do
      require 'elastic_apm/spies/action_dispatch'
    end
  end
end
