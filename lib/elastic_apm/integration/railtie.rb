# frozen_string_literal: true

require 'elastic_apm'

module ElasticAPM
  # @api private
  class Railtie < Rails::Railtie
    config.elastic_apm = ActiveSupport::OrderedOptions.new

    Config::DEFAULTS.each { |key, value| config.elastic_apm[key] = value }

    initializer 'elastic_apm.initialize' do |app|
      config = Config.new app.config.elastic_apm do |c|
        c.logger = Rails.logger
        # c.view_paths = app.config.paths['app/views'].existent
      end

      begin
        ElasticAPM.start config
        Rails.logger.info "#{Log::PREFIX}Running"

        app.middleware.insert 0, Middleware
      rescue StandardError => e
        Rails.logger.error "#{Log::PREFIX}Failed to start\n#{e.message}"
      end
    end
  end
end
