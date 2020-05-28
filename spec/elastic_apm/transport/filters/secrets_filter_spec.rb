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

        it 'removes secret keys from requests' do
          payload = { transaction: { context: { request: { headers: {
            ApiKey: 'very zecret!',
            Untouched: 'very much',
            TotallyNotACreditCard: '4111 1111 1111 1111',
            'HTTP_COOKIE': 'things=1'
          } } } } }

          subject.call(payload)

          headers = payload.dig(:transaction, :context, :request, :headers)

          expect(headers).to match(
            ApiKey: '[FILTERED]',
            Untouched: 'very much',
            TotallyNotACreditCard: '[FILTERED]',
            HTTP_COOKIE: '[FILTERED]'
          )
        end

        it 'removes secret keys from responses' do
          payload = { transaction: { context: { response: { headers: {
            ApiKey: 'very zecret!',
            Untouched: 'very much',
            TotallyNotACreditCard: '4111 1111 1111 1111',
            nested: {
              even_works_token: 'abc'
            },
            secret_array_for_good_measure: [1, 2, 3]
          } } } } }

          subject.call(payload)

          headers = payload.dig(:transaction, :context, :response, :headers)

          expect(headers).to match(
            ApiKey: '[FILTERED]',
            Untouched: 'very much',
            TotallyNotACreditCard: '[FILTERED]',
            nested: { even_works_token: '[FILTERED]' },
            secret_array_for_good_measure: '[FILTERED]'
          )
        end

        it 'removes secrets from form bodies' do
          payload = { transaction: { context: { request: {
            body: { 'api_key' => 'super-secret', 'other' => 'not me' }
          } } } }

          subject.call(payload)

          body = payload.dig(:transaction, :context, :request, :body)
          expect(body).to match('api_key' => '[FILTERED]', 'other' => 'not me')
        end

        context 'with custom_key_filters' do
          before do
            # silence deprecation warning
            allow_any_instance_of(Config).to receive(:warn).with(/DEPRECATED/)
          end

          let(:config) { Config.new(custom_key_filters: [/Authorization/]) }

          it 'removes Authorization header' do
            payload = { transaction: { context: { request: { headers: {
              Authorization: 'Bearer some',
              SomeHeader: 'some'
            } } } } }

            subject.call(payload)

            headers = payload.dig(:transaction, :context, :request, :headers)

            expect(headers).to match(
              Authorization: '[FILTERED]',
              SomeHeader: 'some'
            )
          end
        end

        context 'with sanitize_field_names' do
          let(:config) { Config.new(sanitize_field_names: 'Auth*ion') }

          it 'removes Authorization header' do
            payload = { transaction: { context: { request: { headers: {
              Authorization: 'Bearer some',
              Authentication: 'Polar Bearer some',
              SomeHeader: 'some'
            } } } } }

            subject.call(payload)

            headers = payload.dig(:transaction, :context, :request, :headers)

            expect(headers).to match(
              Authorization: '[FILTERED]',
              Authentication: '[FILTERED]',
              SomeHeader: 'some'
            )
          end
        end
      end
    end
  end
end
