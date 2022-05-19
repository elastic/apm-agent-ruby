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
    module Filters
      RSpec.describe SecretsFilter do
        let(:config) { Config.new }
        subject { described_class.new(config) }

        it 'strips secrets from nested objects' do
          values = {
            body: { ApiKey: '1' },
            env: { ApiKey: '1' },
            cookies: { ApiKey: '1' },
            headers: { ApiKey: '1' }
          }

          payload = {
            transaction: {
              context: {
                request: values,
                response: { headers: { ApiKey: '1' } }
              }
            },
            error: {
              context: {
                request: Util::DeepDup.dup(values),
                response: { headers: { ApiKey: '1', Auth: '2' } }
              }
            },
            something_else: { ApiKey: '1' }
          }

          subject.call(payload)

          expect(payload.dig(:transaction, :context, :request, :body, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:transaction, :context, :request, :cookies, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:transaction, :context, :request, :env, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:transaction, :context, :request, :headers, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:transaction, :context, :response, :headers, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:error, :context, :request, :body, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:error, :context, :request, :cookies, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:error, :context, :request, :env, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:error, :context, :request, :headers, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:error, :context, :response, :headers, :ApiKey)).to eq '[FILTERED]'
          expect(payload.dig(:error, :context, :response, :headers, :Auth)).to eq '[FILTERED]'
          expect(payload.dig(:something_else, :ApiKey)).to eq '1'
        end

        context 'with custom sanitize_field_names' do
          let(:config) { Config.new(sanitize_field_names: 'Auth*ion') }

          it 'filters custom fields' do
            payload = {
              transaction: {
                context: {
                  request: {
                    headers: {
                      Authorization: '1',
                      Authentication: 2,
                      SomethingElse: 3
                    }
                  }
                }
              }
            }

            subject.call(payload)

            expect(payload.dig(:transaction, :context, :request, :headers, :Authorization)).to eq '[FILTERED]'
            expect(payload.dig(:transaction, :context, :request, :headers, :Authentication)).to eq '[FILTERED]'
            expect(payload.dig(:transaction, :context, :request, :headers, :SomethingElse)).to eq 3
          end
        end
      end
    end
  end
end
