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
      RSpec.describe TransactionSerializer do
        let(:builder) { described_class.new Config.new }

        before do
          @mock_uuid = SecureRandom.uuid
          allow(SecureRandom).to receive(:uuid) { @mock_uuid }
        end

        describe '#build', :mock_time do
          context 'a transaction without spans', :intercept do
            let(:transaction) do
              with_agent do
                ElasticAPM.with_transaction('GET /something', 'request') do |t|
                  travel 10_000
                  t.result = '200'
                end
              end

              @intercepted.transactions.first
            end

            subject { builder.build(transaction) }

            it 'builds' do
              should match(
                transaction: {
                  "id": /.{16}/,
                  "name": 'GET /something',
                  "type": 'request',
                  "result": '200',
                  "outcome": 'success',
                  "context": nil,
                  "duration": 10,
                  "timestamp": 694_224_000_000_000,
                  "trace_id": transaction.trace_id,
                  "sampled": true,
                  "sample_rate": 1.0,
                  "span_count": {
                    "started": 0,
                    "dropped": 0
                  },
                  "parent_id": nil
                }
              )
            end
          end

          context 'with dropped spans', :intercept do
            it 'includes count' do
              with_agent(transaction_max_spans: 2) do
                ElasticAPM.with_transaction 'T' do
                  ElasticAPM.with_span('1') {}
                  ElasticAPM.with_span('2') {}
                  ElasticAPM.with_span('dropped') {}
                end
              end

              transaction = @intercepted.transactions.first
              result = described_class.new(Config.new).build(transaction)

              span_count = result.dig(:transaction, :span_count)
              expect(span_count[:started]).to be 3
              expect(span_count[:dropped]).to be 1
            end
          end
        end
      end
    end
  end
end
