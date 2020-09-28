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

  RSpec.describe 'Rails console', :spec_logger do
    before :all do
      class RailsConsoleTestApp < Rails::Application
        RailsTestHelpers.setup_rails_test_config(config)

        config.elastic_apm.disable_send = true
        config.logger = Logger.new(SpecLogger)
      end

      # rubocop:disable Style/ClassAndModuleChildren
      class ::ApplicationController < ActionController::Base; end
      class ::Rails::Console; end
      # rubocop:enable Style/ClassAndModuleChildren

      RailsConsoleTestApp.initialize!
    end

    after :all do
      ElasticAPM.stop
    end

    it "doesn't start when console" do
      expect(ElasticAPM.agent).to be nil
    end
  end
end
