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
  enabled = true
else
  puts '[INFO] Skipping Rails spec'
end

if enabled
  require 'action_controller/railtie'

  RSpec.xdescribe 'Rails integration', :allow_running_agent, :spec_logger do
    include Rack::Test::Methods
    include_context 'event_collector'

    let(:app) do
      Rails.application
    end

    after :all do
      ElasticAPM.stop
      ElasticAPM::Transport::Worker.adapter = nil
    end

    before :all do
      module RailsTestApp
        class Application < Rails::Application
          RailsTestHelpers.setup_rails_test_config(config)

          config.elastic_apm.api_request_time = '200ms'
          config.elastic_apm.disable_start_message = true
          config.elastic_apm.metrics_interval = '1s'
          config.elastic_apm.pool_size = Concurrent.processor_count
          config.elastic_apm.log_path = 'spec/elastic_apm.log'
        end
      end

      class ApplicationController < ActionController::Base
        def index
          render_ok
        end

        def other
          render_ok
        end

        private

        def render_ok
          if Rails.version.start_with?('4')
            render text: 'Yes!'
          else
            render plain: 'Yes!'
          end
        end
      end

      ElasticAPM::Transport::Worker.adapter = EventCollector::TestAdapter

      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        get '/other', to: 'application#other'
        root to: 'application#index'
      end
    end

    it 'handles multiple threads' do
      request_count = 20

      paths = ['/', '/other']

      count = Concurrent::AtomicFixnum.new

      Array.new(request_count).map do
        Thread.new do
          env = Rack::MockRequest.env_for(paths.sample)
          status, = Rails.application.call(env)
          # The request is occasionally unsuccessful so we want to only
          # compare the metricset counts to the number of successful
          # requests.
          count.increment if status == 200
        end
      end.each(&:join)

      sleep 2 # wait for metrics to collect
      expect(EventCollector.metricsets_summary.values).to eq(
        Array.new(5).map { count.value }
      )
    end
  end
end
