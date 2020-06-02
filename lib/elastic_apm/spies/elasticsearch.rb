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
    class ElasticsearchSpy
      NAME_FORMAT = '%s %s'
      TYPE = 'db'
      SUBTYPE = 'elasticsearch'

      def self.sanitizer
        @sanitizer ||= ElasticAPM::Transport::Filters::HashSanitizer.new
      end

      def install
        ::Elasticsearch::Transport::Client.class_eval do
          alias perform_request_without_apm perform_request

          def perform_request(method, path, *args, &block)
            name = format(NAME_FORMAT, method, path)
            statement = []

            statement << { params: args&.[](0) }

            if ElasticAPM.agent.config.capture_elasticsearch_queries
              unless args[1].nil? || args[1].empty?
                statement << {
                  body: ElasticAPM::Spies::ElasticsearchSpy.sanitizer.strip_from!(args[1])
                }
              end
            end

            context = Span::Context.new(
              db: { statement: statement.reduce({}, :merge).to_json },
              destination: {
                name: SUBTYPE,
                resource: SUBTYPE,
                type: TYPE
              }
            )

            ElasticAPM.with_span(
              name,
              TYPE,
              subtype: SUBTYPE,
              context: context
            ) { perform_request_without_apm(method, path, *args, &block) }
          end
        end
      end
    end

    register(
      'Elasticsearch::Transport::Client',
      'elasticsearch-transport',
      ElasticsearchSpy.new
    )
  end
end
