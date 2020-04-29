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

require 'elastic_apm/sql'

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SequelSpy
      TYPE = 'db'
      ACTION = 'query'

      def self.summarizer
        @summarizer = Sql.summarizer
      end

      def install
        require 'sequel/database/logging'

        ::Sequel::Database.class_eval do
          alias log_connection_yield_without_apm log_connection_yield

          def log_connection_yield(sql, connection, args = nil, &block)
            unless ElasticAPM.current_transaction
              return log_connection_yield_without_apm(
                sql, connection, args, &block
              )
            end

            subtype = database_type.to_s

            name =
              ElasticAPM::Spies::SequelSpy.summarizer.summarize sql

            context = ElasticAPM::Span::Context.new(
              db: { statement: sql, type: 'sql', user: opts[:user] },
              destination: { name: subtype, resource: subtype, type: TYPE }
            )

            span = ElasticAPM.start_span(
              name,
              TYPE,
              subtype: subtype,
              action: ACTION,
              context: context
            )
            yield.tap do |result|
              if name =~ /^(UPDATE|DELETE)/
                if connection.respond_to?(:changes)
                  span.context.db.rows_affected = connection.changes
                elsif result.is_a?(Integer)
                  span.context.db.rows_affected = result
                end
              end
            end
          ensure
            ElasticAPM.end_span
          end
        end
      end
    end

    register 'Sequel', 'sequel', SequelSpy.new
  end
end
