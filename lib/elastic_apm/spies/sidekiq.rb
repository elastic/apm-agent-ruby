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
          transaction = ElasticAPM.start_transaction(name, 'Sidekiq', trace_context: get_trace_context_from(job))
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

        private

        def get_trace_context_from(job)
          return unless job['elastic_trace_context']

          ElasticAPM::TraceContext.parse(metadata: job['elastic_trace_context'])
        end
      end

      # @api private
      class ClientMiddleware
        def call(_worker_class, job, _queue, _redis_pool)
          job['elastic_trace_context'] = elastic_trace_context
          yield
        end

        private

        def elastic_trace_context
          return unless ElasticAPM.current_transaction

          trace_context = ElasticAPM.current_transaction.trace_context

          {
            'traceparent' => trace_context.traceparent.to_header,
            'tracestate' => trace_context.tracestate.to_header
          }
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
          config.server_middleware do |chain|
            chain.add ClientMiddleware
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
