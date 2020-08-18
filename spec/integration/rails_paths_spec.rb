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

require 'spec_helper'

if defined?(Rails)
  require 'action_controller/railtie'

  RSpec.describe 'Rails paths' do
    before :all do
      module RailsTestApp
        class Application < Rails::Application
          configure_rails_for_test

          config.disable_send = true

          config.elastic_apm.logger = Logger.new(nil)
          config.logger = Logger.new(nil)
        end
      end

      class ApplicationController < ActionController::Base
      end
    end

    before do
      allow(RailsTestApp::Application.config.paths['app/views'])
        .to receive(:existent).and_return(['test/path'])
      allow(Rails).to receive(:root).and_return(Pathname.new('rootz'))

      RailsTestApp::Application.initialize!
    end

    after do
      ElasticAPM.stop
    end

    it 'sets the paths' do
      expect(ElasticAPM.agent.config.__view_paths.first).to match(%r{test/path})
      expect(ElasticAPM.agent.config.__root_path).to eq('rootz')
    end
  end
end
