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

module ElasticAPM
  RSpec.describe Context::Response do
    let(:response) do
      described_class.new(
        nil,
        headers: headers
      )
    end

    let(:headers) do
      {
        a: 1,
        b: '2',
        c: [1, 2, 3]
      }
    end

    it 'converts header values to string' do
      expect(response.headers).to match(
        a: '1',
        b: '2',
        c: '[1, 2, 3]'
      )
    end

    context 'when headers are nil' do
      let(:headers) { nil }
      it 'sets headers to nil' do
        expect(response.headers).to eq(nil)
      end
    end
  end
end
