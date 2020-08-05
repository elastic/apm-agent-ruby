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
    class DelayedJobSpy
      CLASS_SEPARATOR = '.'
      METHOD_SEPARATOR = '#'
      TYPE = 'Delayed::Job'

      def install
        ::Delayed::Backend::Base.class_eval do
          alias invoke_job_without_apm invoke_job

          def invoke_job(*args, &block)
            ::ElasticAPM::Spies::DelayedJobSpy
              .invoke_job(self, *args, &block)
          end
        end
      end

      def self.invoke_job(job, *args, &block)
        name = job_name(job)
        transaction = ElasticAPM.start_transaction(name, TYPE)
        job.invoke_job_without_apm(*args, &block)
        transaction.done 'success'
      rescue ::Exception => e
        ElasticAPM.report(e, handled: false)
        transaction.done 'error'
        raise
      ensure
        ElasticAPM.end_transaction
      end

      def self.job_name(job)
        if job.payload_object.is_a?(::Delayed::PerformableMethod)
          job.name
        else
          job.payload_object.class.name
        end
      end
    end

    register(
      'Delayed::Backend::Base',
      'delayed/backend/base',
      DelayedJobSpy.new
    )
  end
end
