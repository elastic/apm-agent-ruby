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

require 'active_support/notifications'
require 'elastic_apm/normalizers'

module ElasticAPM
  # @api private
  class Subscriber
    include Logging

    def initialize(agent)
      @agent = agent
      @normalizers = Normalizers.build(agent.config)
    end

    def register!
      unregister! if @subscription

      @subscription =
        ActiveSupport::Notifications.subscribe(notifications_regex, self)
    end

    def unregister!
      ActiveSupport::Notifications.unsubscribe @subscription
      @subscription = nil
    end

    # AS::Notifications API

    Notification = Struct.new(:id, :span)

    def start(name, id, payload)
      return unless (transaction = @agent.current_transaction)

      normalized = @normalizers.normalize(transaction, name, payload)

      span =
        if normalized == :skip
          nil
        else
          name, type, subtype, action, context = normalized

          @agent.start_span(
            name,
            type,
            subtype: subtype,
            action: action,
            context: context
          )
        end

      transaction.notifications << Notification.new(id, span)
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def finish(name, id, payload)
      # debug "AS::Notification#finish:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      while (notification = transaction.notifications.pop)
        next unless notification.id == id

        if (span = notification.span)
          if @agent.config.span_frames_min_duration?
            span.original_backtrace ||= @normalizers.backtrace(name, payload)
          end
          @agent.end_span if span == @agent.current_span
        end
        return
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # @deprecated provide `call` method for Rails 3 backward compatibility
    # instead of having start and finish, rails 3 only calls `call` method
    # so we have to be creative and fixup the start span
    def call(name, start_time, finish_time, id, payload)
      return unless (transaction = @agent.current_transaction)
      # create start event and then fixup the recorded times in the span
      notifications = start(name, id, payload)
      span = notifications.last.span

      if span
        # set timestamp to match start_time
        start_micros = Util.micros(start_time)
        span.timestamp = start_micros

        # when setting clock_start we have to be more careful because clock_start uses monotonic time and the values we get
        # are relative to different origin than what normal Time.now uses
        finish_micros = Util.micros(finish_time)
        duration = finish_micros - start_micros
        # set clock start relative to monotonic time source by subtracting the event duration
        span.clock_start = Util.monotonic_micros - duration
      end

      finish(name, id, payload)
    end

    private

    def notifications_regex
      @notifications_regex ||= /(#{@normalizers.keys.join('|')})/
    end
  end
end
