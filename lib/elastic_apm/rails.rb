# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'elastic_apm/railtie'
require 'elastic_apm/subscriber'
require 'elastic_apm/normalizers/rails'

module ElasticAPM
  # Module for explicitly starting the ElasticAPM agent and hooking into Rails.
  # It is recommended to use the Railtie instead.
  module Rails
    extend self
    # Start the ElasticAPM agent and hook into Rails.
    # Note that the agent won't be started if the Rails console is being used.
    #
    # @param app [::Rails::Application] The Rails application.
    # @param config [Config, Hash] An instance of Config or a Hash config.
    # @return [true, nil] true if the agent was started, nil otherwise.
    def start(app, config)
      config = Config.new(config) unless config.is_a?(Config)
      configure_app(app, config)

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

    private

    def should_skip?(_config)
      if ::Rails.const_defined?('Console', false)
        return 'Rails console'
      end

      nil
    end

    def attach_subscriber(agent)
      return unless agent

      agent.instrumenter.subscriber = ElasticAPM::Subscriber.new(agent)
    end

    def configure_app(app, config)
      config.service_name ||= format_name(rails_app_name(app))
      config.framework_name ||= 'Ruby on Rails'
      config.framework_version ||= ::Rails::VERSION::STRING
      config.logger ||= ::Rails.logger
      config.logger.level ||= ::Rails.logger.level
      config.__root_path = ::Rails.root.to_s
      config.__view_paths = app.config.paths['app/views'].existent
    end

    def format_name(str)
      str&.gsub('::', '_')
    end

    def rails_app_name(app)
      if ::Rails::VERSION::MAJOR >= 6
        app.class.module_parent_name
      else
        app.class.parent_name
      end
    end
  end
end
