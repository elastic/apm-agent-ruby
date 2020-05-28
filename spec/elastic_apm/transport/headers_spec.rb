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
    RSpec.describe Headers do
      let(:config) { Config.new }
      subject { described_class.new(config) }

      describe 'to_h' do
        it 'constructs the default headers from config' do
          expect(subject.to_h).to match('User-Agent': String)
        end

        context 'with a secret token' do
          let(:config) { Config.new secret_token: 'TOKEN' }

          it 'includes auth bearer' do
            expect(subject.to_h).to match(
              'User-Agent': String,
              'Authorization': 'Bearer TOKEN'
            )
          end
        end

        context 'with an api key' do
          let(:config) do
            Config.new api_key: 'a_base64_encoded_string'
          end

          it 'includes api key' do
            expect(subject.to_h).to match(
              'User-Agent': String,
              'Authorization': 'ApiKey a_base64_encoded_string'
            )
          end
        end
      end

      describe 'chunked' do
        it 'returns a modified copy' do
          chunked = subject.chunked
          expect(chunked).to_not be subject
          expect(chunked.hash).to_not be subject.hash
          expect(subject['Transfer-Encoding']).to be nil
          expect(chunked['Transfer-Encoding']).to eq 'chunked'
          expect(chunked['Content-Type']).to eq 'application/x-ndjson'
        end

        context 'with compression' do
          it 'sets gzip header' do
            chunked = subject.chunked
            expect(chunked['Content-Encoding']).to eq 'gzip'
          end
        end
      end
    end
  end
end
