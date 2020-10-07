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
  RSpec.describe CentralConfig do
    let(:config) do
      Config.new(
        central_config: true,
        service_name: 'MyApp',
        log_level: Logger::DEBUG,
      )
    end
    subject { described_class.new(config) }

    describe '#start' do
      it 'polls for config' do
        req_stub = stub_response({ transaction_sample_rate: '0.5' })
        subject.start
        subject.promise.wait
        expect(req_stub).to have_been_requested.at_least_once
        subject.stop
      end

      context 'when disabled' do
        let(:config) { Config.new(central_config: false) }

        it 'does nothing' do
          req_stub = stub_response({ transaction_sample_rate: '0.5' })
          subject.start
          expect(subject.promise).to be nil
          expect(req_stub).to_not have_been_requested
          subject.stop
        end
      end
    end

    describe 'stop and start again' do
      before do
        subject.start
        subject.stop
      end
      after { subject.stop }

      it 'restarts fetching the config' do
        req_stub = stub_response({ transaction_sample_rate: '0.5' })
        subject.start
        subject.promise.wait
        expect(req_stub).to have_been_requested.at_least_once
      end
    end

    describe '#fetch_and_apply_config' do
      it 'queries APM Server and applies config' do
        req_stub = stub_response({ transaction_sample_rate: '0.5' })
        expect(config.logger).to receive(:info)
        expect(config.logger).to receive(:debug).twice

        subject.fetch_and_apply_config
        subject.promise.wait

        # why more times, sometimes?
        expect(req_stub).to have_been_requested.at_least_once
        expect(subject.config.transaction_sample_rate).to eq(0.5)
      end

      it 'reverts config if later 404' do
        stub_response({ transaction_sample_rate: '0.5' })

        subject.fetch_and_apply_config
        subject.promise.wait

        stub_response('Not found', response: { status: 404 })

        subject.fetch_and_apply_config
        subject.promise.wait

        expect(subject.config.transaction_sample_rate).to eq(1.0)
      end

      context 'when server responds 200 and cache-control' do
        it 'schedules a new poll' do
          stub_response(
            {},
            response: {
              headers: { 'Cache-Control': 'must-revalidate, max-age=123' }
            }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 123
        end
      end

      context 'when server responds 304' do
        it 'doesn\'t restore config, schedules a new poll' do
          stub_response(
            { transaction_sample_rate: 0.5 },
            response: {
              headers: { 'Cache-Control': 'must-revalidate, max-age=0.1' }
            }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          stub_response(
            nil,
            response: {
              status: 304,
              headers: { 'Cache-Control': 'must-revalidate, max-age=123' }
            }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 123
          expect(subject.config.transaction_sample_rate).to eq(0.5)
        end
      end

      context 'when server sends etag header' do
        it 'includes etag in next request' do
          stub_response(
            nil,
            response: { headers: { 'Etag': '___etag___' } }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          stub_response(
            nil,
            request: { headers: { 'Etag': '___etag___' } }
          )

          subject.fetch_and_apply_config
          subject.promise.wait
        end
      end

      context 'when server responds 404' do
        it 'schedules a new poll' do
          stub_response('Not found', response: { status: 404 })

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 300
        end
      end

      context 'when there is a network error' do
        it 'schedules a new poll' do
          stub_response(nil, error: HTTP::ConnectionError)

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 300
        end
      end
    end

    describe '#fetch_config' do
      context 'when successful' do
        it 'returns response object' do
          stub_response({ ok: 1 })

          expect(subject.fetch_config).to be_a(HTTP::Response)
        end
      end

      context 'when not found' do
        before do
          stub_response('Not found', response: { status: 404 })
        end

        it 'raises an error' do
          expect { subject.fetch_config }
            .to raise_error(CentralConfig::ClientError)
        end

        it 'includes the response' do
          begin
            subject.fetch_config
          rescue CentralConfig::ClientError => e
            expect(e.response).to be_a(HTTP::Response)
          end
        end
      end

      context 'when server error' do
        it 'raises an error' do
          stub_response('Server error', response: { status: 500 })

          expect { subject.fetch_config }
            .to raise_error(CentralConfig::ServerError)
        end
      end

      context 'with a secret token' do
        before { config.secret_token = 'zecret' }

        it 'sets auth header' do
          stub_response(
            {},
            request: { headers: { 'Authorization': 'Bearer zecret' } }
          )

          subject.fetch_config
        end
      end

      context 'with an api key' do
        before do
          config.api_key = 'a_base64_encoded_string'
        end

        it 'sets auth header' do
          stub_response(
            {},
            request: {
              headers: {
                'Authorization': 'ApiKey a_base64_encoded_string'
              }
            }
          )

          subject.fetch_config
        end
      end
    end

    describe '#assign' do
      it 'updates config' do
        subject.assign(transaction_sample_rate: 0.5)
        expect(subject.config.transaction_sample_rate).to eq(0.5)
      end

      it 'reverts to previous when missing' do
        subject.assign(transaction_sample_rate: 0.5)
        subject.assign({})
        expect(subject.config.transaction_sample_rate).to eq(1.0)
      end

      it 'goes back and forth' do
        subject.assign(transaction_sample_rate: 0.5)
        subject.assign({})
        subject.assign(transaction_sample_rate: 0.5)
        expect(subject.config.transaction_sample_rate).to eq(0.5)
      end
    end

    describe '#handle_forking!' do
      it 'reschedules the scheduled task' do
        req_stub = stub_response({ transaction_sample_rate: '0.5' })

        subject.handle_forking!
        subject.promise.wait
        expect(subject.scheduled_task).to be_pending
        expect(req_stub).to have_been_requested.at_least_once

        subject.stop
      end
    end

    def stub_response(body, request: {}, response: {}, error: nil)
      url = 'http://localhost:8200/config/v1/agents?service.name=MyApp'

      return stub_request(:get, url).to_raise(error) if error

      stub_request(:get, url).tap do |stub|
        stub.with(request) if request.any?
        stub.to_return(body: body&.to_json, **response)
      end
    end
  end
end
