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
require "spec_helper"
require "aws-sdk-dynamodb"

module ElasticAPM
  RSpec.describe "Spy: DynamoDB" do
    let(:dynamo_db_client) do
      ::Aws::DynamoDB::Client.new(stub_responses: true, region: "us-west-1")
    end

    it "spans operations", :intercept do
      with_agent do
        ElasticAPM.with_transaction do
          dynamo_db_client.delete_item(table_name: "test", key: {})
        end
      end

      span = @intercepted.spans.first

      expect(span.name).to eq("DynamoDB DeleteItem test")
      expect(span.type).to eq("db")
      expect(span.subtype).to eq("dynamodb")
      expect(span.action).to eq("query")
      expect(span.outcome).to eq("success")

      # span context db
      expect(span.context.db.instance).to eq("us-west-1")
      expect(span.context.db.statement).to be(nil)
      expect(span.context.db.type).to eq("dynamodb")

      # span context destination
      expect(span.context.destination.address).to eq("dynamodb.us-west-1.amazonaws.com")
      expect(span.context.destination.port).to eq(443)
      expect(span.context.destination.service.name).to eq("dynamodb")
      expect(span.context.destination.service.type).to eq("db")
      expect(span.context.destination.service.resource).to eq("dynamodb")
      expect(span.context.destination.cloud.region).to eq("us-west-1")
    end

    it "omits the table name when there is none", :intercept do
      with_agent do
        ElasticAPM.with_transaction do
          dynamo_db_client.describe_backup(backup_arn: "test-arn")
        end
      end

      span = @intercepted.spans.first

      expect(span.name).to eq("DynamoDB DescribeBackup")
    end

    it "captures the key_condition_expression for queries", :intercept do
      with_agent do
        ElasticAPM.with_transaction do
          dynamo_db_client.query(
            table_name: "myTable",
            key_condition_expression: "Artist = :v1"
          )
        end
      end

      span = @intercepted.spans.first

      expect(span.name).to eq("DynamoDB Query myTable")
      expect(span.context.db.statement).to eq("Artist = :v1")
    end

    context("when the operation fails") do
      it "sets span outcome to `failure`", :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            begin
              dynamo_db_client.batch_get_item({})
            rescue
            end
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq("DynamoDB BatchGetItem")
        expect(span.outcome).to eq("failure")
      end
    end
  end
end
