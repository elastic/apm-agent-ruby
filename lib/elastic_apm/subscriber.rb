# frozen_string_literal: true

require 'active_support/notifications'
require 'elastic_apm/normalizers'

module ElasticAPM
  # @api private
  class Subscriber
    include Logging

    def initialize(config)
      @normalizers = Normalizers.build(config)
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
      return unless (transaction = ElasticAPM.current_transaction)

      normalized = @normalizers.normalize(transaction, name, payload)

      span =
        if normalized == :skip
          nil
        else
          name, type, subtype, action, context = normalized

          # We call #start_span on the agent, otherwise original_backtrace
          # will be set on the span.
          ElasticAPM.agent.start_span(
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
      return unless (transaction = ElasticAPM.current_transaction)

      while (notification = transaction.notifications.pop)
        next unless notification.id == id

        if (span = notification.span)
          if config.span_frames_min_duration?
            span.original_backtrace ||= @normalizers.backtrace(name, payload)
          end
          ElasticAPM.end_span if span == ElasticAPM.current_span
        end
        return
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def notifications_regex
      @notifications_regex ||= /(#{@normalizers.keys.join('|')})/
    end

    def config
      ElasticAPM.config
    end
  end
end
