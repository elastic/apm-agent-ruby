# frozen_string_literal: true

module ElasticAPM
  # Module for starting the ElasticAPM agent and hooking into Sinatra.
  module Sinatra
    extend self
    # Start the ElasticAPM agent and hook into Sinatra.
    #
    # @param app [Sinatra::Base] A Sinatra app.
    # @param config [Config, Hash] An instance of Config or a Hash config.
    # @return [true, nil] true if the agent was started, nil otherwise.
    def start(app, config = {})
      config = Config.new(config) unless config.is_a?(Config)
      configure_app(app, config)

      ElasticAPM.start(config)
      ElasticAPM.running?
    rescue StandardError => e
      config.logger.error format('Failed to start: %s', e.message)
      config.logger.debug "Backtrace:\n" + e.backtrace.join("\n")
    end

    private

    def configure_app(app, config)
      config.service_name ||= format_name(app.to_s)
      config.framework_name ||= 'Sinatra'
      config.framework_version ||= ::Sinatra::VERSION
      config.__root_path ||= Dir.pwd
    end

    def format_name(str)
      str && str.gsub('::', '_')
    end
  end
end
