# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Railtie < Rails::Railtie
    config.elastic_apm = ActiveSupport::OrderedOptions.new
    Config::DEFAULTS.each { |option, value| config.elastic_apm[option] = value }

    initializer 'elastic_apm.initialize' do |app|
      config = Config.new app.config.elastic_apm do |c|
        c.app_name = Rails.application.class.parent_name || c.app_name
        c.logger = Rails.logger
        c.view_paths = app.config.paths['app/views'].existent
      end

      file_config = load_config(app)
      file_config.each do |option, value|
        config.send(:"#{option}=", value)
      end

      begin
        ElasticAPM.start config
        Rails.logger.info "#{Log::PREFIX}Running"

        app.middleware.insert 0, Middleware
      rescue StandardError => e
        Rails.logger.error "#{Log::PREFIX}Failed to start: #{e.message}"
        Rails.logger.debug e.backtrace.join("\n")
      end
    end

    config.after_initialize do
      require 'elastic_apm/injectors/action_dispatch'
    end

    private

    def load_config(app)
      config_path = app.root.join('config', 'elastic_apm.yml')
      return {} unless File.exist?(config_path)

      YAML.load_file(config_path) || {}
    end
  end
end
