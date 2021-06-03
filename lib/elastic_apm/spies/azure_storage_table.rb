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

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class AzureStorageTableSpy
      TYPE = "storage"
      SUBTYPE = "azuretable"

      module Helpers
        @@formatted_op_names = Concurrent::Map.new
        @@account_names = Concurrent::Map.new

        def self.span_name(operation_name, table_name = nil)
          base = "AzureTable #{formatted_op_name(operation_name)}"

          return base unless table_name

          "#{base} #{table_name}"
        end

        def self.formatted_op_name(operation_name)
          @@formatted_op_names.compute_if_absent(operation_name) do
            operation_name.to_s.split("_").collect(&:capitalize).join
          end
        end

        def self.account_name_from_storage_table_host(host)
          @@account_names.compute_if_absent(host) do
            URI(host).host.split(".").first || "unknown"
          end
        rescue Exception
          "unknown"
        end
      end

      # @api private
      module Ext
        def get_entity(table_name, *args)
          unless (transaction = ElasticAPM.current_transaction)
            return super(table_name, *args)
          end

          operation_name = "get_entity"

          helpers = ElasticAPM::Spies::AzureStorageTableSpy::Helpers
          span_name = helpers.span_name(operation_name, table_name)
          action = helpers.formatted_op_name(operation_name)
          account_name = helpers.account_name_from_storage_table_host(storage_service_host[:primary])

          # Parse cloud info from endpoint url?
          # pp(storage_service_host)
          destination = ElasticAPM::Span::Context::Destination.from_uri(storage_service_host[:primary])
          destination.service.resource = "#{SUBTYPE}/#{account_name}"

          context = ElasticAPM::Span::Context.new(destination: destination)

          ElasticAPM.with_span(span_name, TYPE, subtype: SUBTYPE, action: action, context: context) do
            ElasticAPM::Spies.without_faraday do
              ElasticAPM::Spies.without_net_http do
                super(table_name, *args)
              end
            end
          end

          # end
        end
      end

      def install
        ::Azure::Storage::Table::TableService.prepend(Ext)
      end
    end

    register(
      "Azure::Storage::Table::TableService",
      "azure/storage/table",
      AzureStorageTableSpy.new
    )
  end
end
