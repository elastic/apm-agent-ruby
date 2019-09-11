# frozen_string_literal: true

require 'elastic_apm/rails'

module ElasticAPM
  # @api private
  class Railtie < ::Rails::Railtie
    config.elastic_apm = ActiveSupport::OrderedOptions.new

    Config.schema.each do |key, args|
      next unless args.length > 1
      config.elastic_apm[key] = args.last[:default]
    end

    initializer 'elastic_apm.initialize' do |app|
      config = Config.new(app.config.elastic_apm).tap do |c|
        c.app = app

        # Prepend Rails.root to log_path if present
        if c.log_path && !c.log_path.start_with?('/')
          c.log_path = ::Rails.root.join(c.log_path)
        end
      end

      if Rails.start(config)
        app.middleware.insert 0, Middleware
      end
    end
  end
end
