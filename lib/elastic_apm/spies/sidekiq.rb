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
    class SidekiqSpy
      ACTIVE_JOB_WRAPPER =
        'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper'
      ACTIVE_JOB_WRAPPER_V8 = 'Sidekiq::ActiveJob::Wrapper'

      # @api private
      class Middleware
        def call(_worker, job, queue)
          name = SidekiqSpy.name_for(job)
          transaction = if job['trace_id']
            ElasticAPM.start_transaction(name, 'Sidekiq', trace_context: ElasticAPM::TraceContext.new(
              traceparent: ElasticAPM::TraceContext::Traceparent.new(trace_id: job['trace_id'])
            ))
          else
            ElasticAPM.start_transaction(name, 'Sidekiq')
          end
          ElasticAPM.set_label(:queue, queue)

          yield

          transaction&.done :success
          transaction&.outcome = Transaction::Outcome::SUCCESS
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction&.done :error
          transaction&.outcome = Transaction::Outcome::FAILURE
          raise
        ensure
          ElasticAPM.end_transaction
        end
      end

      class ParentTraceMiddleware
        def call(job_class_or_string, job, queue, redis_pool)
          job.merge!(
            'trace_id' => ElasticAPM.current_transaction&.trace_id
          )
        end
      end

      def self.name_for(job)
        klass = job['class']

        case klass
        when ACTIVE_JOB_WRAPPER, ACTIVE_JOB_WRAPPER_V8
          job['wrapped']
        else
          klass
        end
      end

      def install_middleware
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Middleware
          end
        end

        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
             chain.add ParentTraceMiddleware
          end
        end
      end

      # @api private
      module Ext
        def start
          super.tap do
            # Already running from Railtie if Rails
            if ElasticAPM.running?
              ElasticAPM.agent.config.logger = Sidekiq.logger
            else
              ElasticAPM.start
            end
          end
        end

        def terminate
          super.tap do
            ElasticAPM.stop
          end
        end
      end

      def install_processor
        require 'sidekiq/processor'

        Sidekiq::Processor.prepend(Ext)
      end

      def install
        install_processor
        install_middleware
      end
    end

    register 'Sidekiq', 'sidekiq', SidekiqSpy.new
  end
end
