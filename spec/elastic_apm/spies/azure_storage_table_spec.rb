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
      common_client = ::Azure::Storage::Common::Client.create(
        storage_account_name: 'abc',
        storage_access_key: Base64.encode64('xyz'),
        storage_table_host: 'https://my-account.table.core.windows.net'
      )

      ::Azure::Storage::Table::TableService.new(client: common_client)
    end

    def stub_server(path:, body: {})
      stub_request(
        :get,
        "https://my-account.table.core.windows.net#{path}"
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

      expect(@intercepted.spans.length).to be 1

      span, = @intercepted.spans

      expect(span.name).to eq('AzureTable GetEntity testtable')
      expect(span.type).to eq('storage')
      expect(span.subtype).to eq('azuretable')
      expect(span.action).to eq('GetEntity')
      expect(span.outcome).to eq('success')

      # span context destination
      expect(span.context.destination.address).to eq('my-account.table.core.windows.net')
      expect(span.context.destination.port).to eq(443)
      expect(span.context.destination.service.resource).to eq('azuretable/my-account')

      # deprecated fields will be filled in later
      expect(span.context.destination.service.name).to be nil
      expect(span.context.destination.service.type).to be nil

      expect(@stub).to have_been_requested
    end
  end
end
