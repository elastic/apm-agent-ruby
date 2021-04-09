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
require 'azure/storage/table'

module ElasticAPM
  RSpec.describe 'Spy: Azure Storage Table' do
    let(:client) do
      common = ::Azure::Storage::Common::Client.create_development
      ::Azure::Storage::Table::TableService.new(client: common)
    end

    def stub_server(path:, body: {})
      stub_request(
        :get,
        "http://127.0.0.1:10002/devstoreaccount1#{path}"
      ).to_return(body: body.to_json)
    end

    it "spans operations", :intercept do
      @stub =
        stub_server(path: "/testtable(PartitionKey='test-partition-key',RowKey='1')")

      with_agent do
        ElasticAPM.with_transaction do
          client.get_entity("testtable", "test-partition-key", "1")
        end
      end

      span = @intercepted.spans.first

      expect(span.name).to eq('AzureStorageTable get_entity testtable')
      # expect(span.type).to eq('db')
      # expect(span.subtype).to eq('dynamodb')
      # expect(span.action).to eq(:delete_item)
      # expect(span.outcome).to eq('success')

      # # span context db
      # expect(span.context.db.instance).to eq('us-west-1')
      # expect(span.context.db.type).to eq('dynamodb')

      # # span context destination
      # expect(span.context.destination.cloud.region).to eq('us-west-1')
      # expect(span.context.destination.resource).to eq('dynamodb')
      # expect(span.context.destination.type).to eq('db')

      expect(@stub).to have_been_requested
    end
  end
end
