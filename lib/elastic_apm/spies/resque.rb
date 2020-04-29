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
    class ResqueSpy
      TYPE = 'Resque'

      def install
        install_perform_spy
        install_after_fork_hook
      end

      def install_after_fork_hook
        ::Resque.after_fork do
          ElasticAPM.restart
        end
      end

      def install_perform_spy
        ::Resque::Job.class_eval do
          alias :perform_without_elastic_apm :perform

          def perform
            name = @payload && @payload['class']&.to_s
            transaction = ElasticAPM.start_transaction(name, TYPE)
            perform_without_elastic_apm
            transaction.done 'success'
          rescue ::Exception => e
            ElasticAPM.report(e, handled: false)
            transaction.done 'error'
            raise
          ensure
            ElasticAPM.end_transaction
          end
        end
      end
    end

    register 'Resque', 'resque', ResqueSpy.new
  end
end
