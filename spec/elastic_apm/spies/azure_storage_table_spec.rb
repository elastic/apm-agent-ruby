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
#
# frozen_string_literal: true

require "spec_helper"

require "azure/storage/table"

module ElasticAPM
  RSpec.describe "Spy: Azure Storage Table" do
    let(:client) do
      common_client = ::Azure::Storage::Common::Client.create(
        storage_account_name: "abc",
        # lib validates valid Base64
        storage_access_key: Base64.encode64("xyz"),
        storage_table_host: "https://my-account.table.core.windows.net"
      )

      ::Azure::Storage::Table::TableService.new(client: common_client)
    end

    def stub_server(method, path, body: {})
      stub = stub_request(
        method,
        "https://my-account.table.core.windows.net#{path}"
      ).to_return(body: body&.to_json)

      yield

      expect(stub).to have_been_requested
    end

    describe '#create_table', :intercept do
      it 'adds a span' do
        stub_server(:post, "/Tables") do
          with_agent do
            ElasticAPM.with_transaction do
              client.create_table("testtable")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable CreateTable testtable")
        expect(span.type).to eq("storage")
        expect(span.subtype).to eq("azuretable")
        expect(span.action).to eq("CreateTable")
        expect(span.outcome).to eq("success")

        # span context destination
        expect(span.context.destination.address).to eq("my-account.table.core.windows.net")
        expect(span.context.destination.port).to eq(443)
        expect(span.context.destination.service.resource).to eq("azuretable/my-account")
      end
    end

    describe "#delete_table", :intercept do
      it 'adds a span' do
        stub_server(:delete, "/Tables('testtable')") do
          with_agent do
            ElasticAPM.with_transaction do
              client.delete_table("testtable")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable DeleteTable testtable")
        expect(span.action).to eq("DeleteTable")
      end
    end

    describe "#get_table", :intercept do
      it 'adds a span' do
        stub_server(:get, "/Tables('testtable')") do
          with_agent do
            ElasticAPM.with_transaction do
              client.get_table("testtable")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable GetTable testtable")
        expect(span.action).to eq("GetTable")
      end
    end

    describe "#get_table_acl", :intercept do
      it 'adds a span' do
        stub_server(:get, "/testtable?comp=acl", body: nil) do
          with_agent do
            ElasticAPM.with_transaction do
              client.get_table_acl("testtable")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable GetTableAcl testtable")
        expect(span.action).to eq("GetTableAcl")
      end
    end

    describe "#set_table_acl", :intercept do
      it 'adds a span' do
        stub_server(:put, "/testtable?comp=acl") do
          with_agent do
            ElasticAPM.with_transaction do
              client.set_table_acl("testtable")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable SetTableAcl testtable")
        expect(span.action).to eq("SetTableAcl")
      end
    end

    describe "#insert_entity", :intercept do
      it 'adds a span' do
        stub_server(:post, "/testtable()", body: { "best" => "true" }) do
          with_agent do
            ElasticAPM.with_transaction do
              client.insert_entity("testtable", {best: "true"})
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable InsertEntity testtable")
        expect(span.action).to eq("InsertEntity")
      end
    end

    describe "#query_entities", :intercept do
      it 'adds a span' do
        stub_server(:get, "/testtable()") do
          with_agent do
            ElasticAPM.with_transaction do
              client.query_entities("testtable")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable QueryEntities testtable")
        expect(span.action).to eq("QueryEntities")
      end
    end

    describe "#update_entity", :intercept do
      it 'adds a span' do
        stub_server(:put, "/testtable()") do
          with_agent do
            ElasticAPM.with_transaction do
              client.update_entity("testtable", {best: "true"})
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable UpdateEntity testtable")
        expect(span.action).to eq("UpdateEntity")
      end
    end

    describe "#merge_entity", :intercept do
      it 'adds a span' do
        stub_server(:post, "/testtable()") do
          with_agent do
            ElasticAPM.with_transaction do
              client.merge_entity("testtable", {best: "true"})
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable MergeEntity testtable")
        expect(span.action).to eq("MergeEntity")
      end
    end

    describe "#delete_entity", :intercept do
      it 'adds a span' do
        stub_server(:delete, "/testtable(PartitionKey='test-partition-key',RowKey='1')") do
          with_agent do
            ElasticAPM.with_transaction do
              client.delete_entity("testtable", "test-partition-key", "1")
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable DeleteEntity testtable")
        expect(span.action).to eq("DeleteEntity")
      end
    end

    describe "#get_entity", :intercept do
      it 'adds a span' do
        stub_server(:get, "/testtable(PartitionKey='test-partition-key',RowKey='1')") do
          with_agent do
            ElasticAPM.with_transaction do
              client.get_entity("testtable", "test-partition-key", "1")
            end
          end
        end

        expect(@intercepted.spans.length).to be(2)
        q_span, span = @intercepted.spans

        expect(q_span.name).to eq("AzureTable QueryEntities testtable")
        expect(q_span.action).to eq("QueryEntities")
        expect(span.name).to eq("AzureTable GetEntity testtable")
        expect(span.action).to eq("GetEntity")
      end
    end

    describe "#query_tables", :intercept do
      it 'adds a span' do
        stub_server(:get, "/Tables") do
          with_agent do
            ElasticAPM.with_transaction do
              client.query_tables()
            end
          end
        end

        expect(@intercepted.spans.length).to be(1)
        span, = @intercepted.spans

        expect(span.name).to eq("AzureTable QueryTables")
        expect(span.action).to eq("QueryTables")
      end
    end
  end
end
