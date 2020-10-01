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

require 'integration_helper'

if defined?(Rails)
  require 'action_controller/railtie'

  RSpec.describe 'Rails logger', :allow_running_agent, :mock_intake do
    before :all do
      module RailsTestApp
        class Application < Rails::Application
          RailsTestHelpers.setup_rails_test_config(config)

          config.disable_send = true

          config.elastic_apm.logger = Logger.new(nil)
          config.logger = Logger.new(nil)
        end
      end

      class ApplicationController < ActionController::Base
      end

      MockIntake.stub!

      RailsTestApp::Application.initialize!
    end

    after :all do
      ElasticAPM.stop
    end

    it 'sets the custom logger' do
      expect(Rails.logger).not_to be(ElasticAPM.agent.config.logger)
    end
  end
end
