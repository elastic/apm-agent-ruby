# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Railtie < Rails::Railtie
    config.elastic_apm = ActiveSupport::OrderedOptions.new
    Config::DEFAULTS.each { |option, value| config.elastic_apm[option] = value }

    initializer 'elastic_apm.initialize' do |app|
      config = app.config.elastic_apm.merge(app: app)

      begin
        ElasticAPM.start config

        app.middleware.insert 0, Middleware
      rescue StandardError => e
        Rails.logger.error "#{Log::PREFIX}Failed to start: #{e.message}"
        Rails.logger.debug e.backtrace.join("\n")
      end
    end

    config.after_initialize do
      require 'elastic_apm/spies/action_dispatch'
    end
  end
end
