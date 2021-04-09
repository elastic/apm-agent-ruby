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
  # @api private
  module Spies
    # @api private
    class AzureStorageTableSpy
      TYPE = 'db'
      SUBTYPE = 'azurestoragetable'

      @@formatted_op_names = Concurrent::Map.new

      def self.span_name(operation_name, table_name = nil)
        base = "AzureStorageTable #{formatted_op_name(operation_name)}"

        return base unless table_name

        "#{base} #{table_name}"
      end

      def self.formatted_op_name(operation_name)
        operation_name
        # @@formatted_op_names.compute_if_absent(operation_name) do
        #   operation_name.to_s.split('_').collect(&:capitalize).join
        # end
      end

      # @api private
      module Ext
        def get_entity(table_name, partition_key, row_key, options = {})
          unless (transaction = ElasticAPM.current_transaction)
            return super(table_name, partition_key, row_key, options)
          end

          operation_name = "get_entity"
          span_name = ElasticAPM::Spies::AzureStorageTableSpy.span_name(operation_name, table_name)

          # Parse cloud info from endpoint url?
          pp storage_service_host
          # cloud = ElasticAPM::Span::Context::Destination::Cloud.new(region: config.region)

          context = ElasticAPM::Span::Context.new(
            db: {
              instance: storage_service_host[:primary],
              type: SUBTYPE
            },
            destination: {
              # cloud: cloud,
              resource: SUBTYPE,
              type: TYPE
            }
          )

          ElasticAPM.with_span(span_name, TYPE, subtype: SUBTYPE, action: operation_name, context: nil) do # context) do
            ElasticAPM::Spies.without_faraday do
              # ElasticAPM::Spies.without_net_http do
                super(table_name, partition_key, row_key, options)
              # end
            end
          end
        end
      end

      def install
        ::Azure::Storage::Table::TableService.prepend(Ext)
      end
    end

    register(
      'Azure::Storage::Table::TableService',
      'azure/storage/table',
      AzureStorageTableSpy.new
    )
  end
end
