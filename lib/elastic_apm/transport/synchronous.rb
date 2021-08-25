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

require 'elastic_apm/metadata'
require 'elastic_apm/transport/user_agent'
require 'elastic_apm/transport/headers'
require 'elastic_apm/transport/connection'
require 'elastic_apm/transport/worker'
require 'elastic_apm/transport/serializers'
require 'elastic_apm/transport/filters'
require 'elastic_apm/transport/connection/http'

require 'elastic_apm/util/throttle'

module ElasticAPM
  module Transport
    # @api private
    class Synchronous
      include Logging

      def initialize(config)
        @config = config
        # Todo: What size should the queue be for synchronous sending?
        @queue = SizedQueue.new(config.api_buffer_size)

        @serializers = Serializers.new(config)
        @filters = Filters.new(config)

        @stopped = Concurrent::AtomicBoolean.new
        @worker = Worker.new(
            config, queue,
            serializers: @serializers,
            filters: @filters
        )
      end

      attr_reader :config, :queue, :filters, :worker, :stopped

      def start
        debug '%s: Starting Synchronous Transport', pid_str
        @stopped.make_false unless @stopped.false?
      end

      def stop
        debug '%s: Stopping Transport and flushing events', pid_str

        @stopped.make_true

        send_stop_message
        flush
      end

      def flush
        worker.work_forever
      end

      def submit(resource)
        if @stopped.true?
          warn '%s: Transport stopping, no new events accepted', pid_str
          debug 'Dropping: %s', resource.inspect
          return false
        end

        queue.push(resource, true)

        true
      rescue ThreadError => e
        warn(
          '%s: Queue is full (%i items), skipping…',
          pid_str, config.api_buffer_size
        )
      rescue Exception => e
        error '%s: Failed adding to the transport queue: %p', pid_str, e.inspect
        nil
      end

      def add_filter(key, callback)
        @filters.add(key, callback)
      end

      def handle_forking!
        # We can't just stop and start again because the StopMessage
        # will then be the first message processed when the transport is
        # restarted.
        # Todo: what to do when forking with synchronous transport?
        # stop_watcher
        # ensure_worker_count
        # create_watcher
      end

      private

      def pid_str
        format('[PID:%s]', Process.pid)
      end

      def send_stop_message
        queue.push(Worker::StopMessage.new, true)
      rescue ThreadError
        warn 'Cannot push stop messages to worker queue as it is full'
      end
    end
  end
end
