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
require 'aws-sdk-dynamodb'

module ElasticAPM
  RSpec.describe 'Spy: DynamoDB' do
    let(:dynamo_db_client) do
      ::Aws::DynamoDB::Client.new(stub_responses: true)
    end

    it "spans operations", :intercept do
      with_agent do
        ElasticAPM.with_transaction 'T' do
          dynamo_db_client.update_item(table_name: 'test', key: {})
        end
      end

      span = @intercepted.spans.first

      expect(span.name).to eq(:update_item)
      expect(span.type).to eq('db')
      expect(span.subtype).to eq('dynamodb')
      expect(span.action).to eq(:update_item)
      expect(span.outcome).to eq('success')
    end

    context 'when the operation fails' do
      it 'sets span outcome to `failure`', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            begin
              dynamo_db_client.batch_get_item({})
            rescue
            end
          end
          span = @intercepted.spans.first
          expect(span.outcome).to eq('failure')
        end
      end
    end
  end
end
