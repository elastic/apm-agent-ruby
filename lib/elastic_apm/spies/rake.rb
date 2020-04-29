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
    class RakeSpy
      def install
        ::Rake::Task.class_eval do
          alias execute_without_apm execute

          def execute(*args)
            agent = ElasticAPM.start

            unless agent && agent.config.instrumented_rake_tasks.include?(name)
              return execute_without_apm(*args)
            end

            transaction =
              ElasticAPM.start_transaction("Rake::Task[#{name}]", 'Rake')

            begin
              result = execute_without_apm(*args)

              transaction.result = 'success' if transaction
            rescue StandardError => e
              transaction.result = 'error' if transaction
              ElasticAPM.report(e)

              raise
            ensure
              ElasticAPM.end_transaction
              ElasticAPM.stop
            end

            result
          end
        end
      end
    end
    register 'Rake::Task', 'rake', RakeSpy.new
  end
end
