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
    class SolidQueueSpy
      TYPE = 'SolidQueue'

      # @api private
      module Ext
        def perform
          name = job&.class_name
          transaction = ElasticAPM.start_transaction(name, TYPE)
          ElasticAPM.set_label(:queue, job.queue_name) if job&.queue_name

          super

          transaction&.done 'success'
          transaction&.outcome = Transaction::Outcome::SUCCESS
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction&.done 'error'
          transaction&.outcome = Transaction::Outcome::FAILURE
          raise
        ensure
          ElasticAPM.end_transaction
        end
      end

      def install
        # +SolidQueue::ClaimedExecution+ lives under +app/models+ and is
        # autoloaded via Zeitwerk by the Rails engine.
        #
        # Two hooks are needed:
        #   - +after_initialize+ fires after eager loading in production, which
        #     is when +ClaimedExecution+ is first defined. +to_prepare+ alone is
        #     not enough because Rails runs +to_prepare+ *before* eager loading.
        #   - +to_prepare+ handles code reloads in development so the patch
        #     survives class unloading between reloads.
        #
        # Fork mode (the default solid_queue supervisor) is handled by the agent
        # itself via +Agent#detect_forking!+ on each +start_transaction+, so no
        # extra lifecycle hook wiring is needed here.
        if defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
          ::Rails.application.config.after_initialize { SolidQueueSpy.prepend_ext }
          ::Rails.application.reloader.to_prepare { SolidQueueSpy.prepend_ext }
        end

        SolidQueueSpy.prepend_ext
      end

      def self.prepend_ext
        return unless defined?(::SolidQueue::ClaimedExecution)
        return if ::SolidQueue::ClaimedExecution.include?(Ext)

        ::SolidQueue::ClaimedExecution.prepend(Ext)
      end
    end

    register 'SolidQueue', 'solid_queue', SolidQueueSpy.new
  end
end
