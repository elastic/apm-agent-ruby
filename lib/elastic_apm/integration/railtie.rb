# frozen_string_literal: true

require 'elastic_apm'

module ElasticAPM
  # @api private
  class Railtie < Rails::Railtie
    initializer 'elastic_apm.initialize' do |app|
      ElasticAPM.start Config.new
      app.middleware.insert 0, Middleware
    end
  end
end
