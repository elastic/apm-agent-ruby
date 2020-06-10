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

if defined?(Grape)
  RSpec.describe Grape do
    describe '.start' do
      include_context 'stubbed_central_config'

      before(:all) do
        class GrapeTestApp < ::Grape::API
          use ElasticAPM::Middleware
        end
      end

      after(:all) do
        Object.send(:remove_const, :GrapeTestApp)
      end

      context 'with no overridden config settings' do
        before do
          ElasticAPM::Grape.start(GrapeTestApp, config)
        end

        after do
          ElasticAPM.stop
        end

        let(:config) { {} }
        it 'starts the agent' do
          expect(ElasticAPM::Agent).to be_running
        end
      end

      context 'a config with settings' do
        before do
          ElasticAPM::Grape.start(GrapeTestApp, config)
        end

        after do
          ElasticAPM.stop
        end

        let(:config) { { service_name: 'Other Name' } }

        it 'sets the options' do
          expect(ElasticAPM.agent.config.options[:service_name].value)
            .to eq('Other Name')
        end
      end
    end
  end
end
