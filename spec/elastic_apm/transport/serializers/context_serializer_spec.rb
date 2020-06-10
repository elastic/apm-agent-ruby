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

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe ContextSerializer do
        let(:config) { Config.new }
        subject { described_class.new config }

        it 'converts response.status_code to int' do
          context = Context.new
          context.response = Context::Response.new('302')
          result = subject.build(context)
          expect(result.dig(:response, :status_code)).to be 302
        end

        context 'service' do
          it 'includes the service' do
            context = Context.new
            context.set_service(
              framework_name: 'Grape',
              framework_version: '1.2'
            )
            result = subject.build(context)
            expect(result[:service][:framework][:name]).to eq('Grape')
            expect(result[:service][:framework][:version]).to eq('1.2')
          end
        end
      end
    end
  end
end
