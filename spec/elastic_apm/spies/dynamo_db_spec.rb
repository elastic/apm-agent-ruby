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
    let(:operation_params) do
      {
        batch_get_item: { request_items: {} },
        batch_write_item: { request_items: {} },
        create_backup: { table_name: 'test', backup_name: 'test' },
        create_global_table: {
          global_table_name: 'test',
          replication_group: []
        },
        create_table: {
          table_name: 'test',
          key_schema: {},
          attribute_definitions: {},
          provisioned_throughput: {
            read_capacity_units: 1,
            write_capacity_units: 1
          }
        },
        delete_backup: { backup_arn: '' },
        delete_item: { table_name: 'test', key: {} },
        delete_table: { table_name: 'test' },
        describe_backup: { backup_arn: 'test' },
        describe_continuous_backups: { table_name: 'test' },
        describe_contributor_insights: { table_name: 'test' },
        describe_global_table: { global_table_name: 'test' },
        describe_global_table_settings: { global_table_name: 'test' },
        describe_table: { table_name: 'test' },
        describe_table_replica_auto_scaling: { table_name: 'test' },
        describe_time_to_live: { table_name: 'test' },
        get_item: { table_name: 'test', key: {} },
        list_tags_of_resource: { resource_arn: 'test' },
        put_item: { table_name: 'test', item: {} },
        query: { table_name: 'test' },
        restore_table_from_backup: {
          target_table_name: 'test',
          backup_arn: 'test'
        },
        restore_table_to_point_in_time: {
          source_table_name: 'test',
          target_table_name: 'test'
        },
        scan: { table_name: 'test' },
        tag_resource: { resource_arn: '', tags: [] },
        transact_get_items: { transact_items: {} },
        transact_write_items: { transact_items: {} },
        update_continuous_backups: {
          table_name: 'test',
          point_in_time_recovery_specification: {
            point_in_time_recovery_enabled: true
          }
        },
        update_contributor_insights: {
          table_name: 'test',
          contributor_insights_action: 'test'
        },
        update_global_table: { global_table_name: 'test', replica_updates: {} },
        update_global_table_settings: { global_table_name: 'test' },
        update_item: { table_name: 'test', key: {} },
        untag_resource: { resource_arn: 'test', tag_keys: {} },
        update_table: { table_name: 'test' },
        update_table_replica_auto_scaling: { table_name: 'test' },
        update_time_to_live: {
          table_name: 'test',
          time_to_live_specification: { enabled: true, attribute_name: 'test' }
        }
      }
    end

    ::Aws::DynamoDB::Client.api.operation_names.each do |operation_name|
      it "spans #{operation_name}", :intercept do
        with_agent do
          ElasticAPM.with_transaction 'T' do
            params = operation_params[operation_name] || {}
            dynamo_db_client.send(
              operation_name,
              params,
              { convert_params: true }
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq(operation_name)
        expect(span.type).to eq('db')
        expect(span.subtype).to eq('dynamodb')
        expect(span.action).to eq(operation_name)
      end
    end
  end
end
