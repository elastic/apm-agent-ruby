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
      # debug "AS::Notification#start:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      normalized = @normalizers.normalize(transaction, name, payload)

      span =
        if normalized == :skip
          nil
        else
          name, type, context = normalized
          @agent.start_span(name, type, context: context)
        end

      transaction.notifications << Notification.new(id, span)
    end

    def finish(_name, id, _payload)
      # debug "AS::Notification#finish:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      while (notification = transaction.notifications.pop)
        next unless notification.id == id

        if (span = notification.span)
          @agent.end_span if span == @agent.current_span
        end
        return
      end
    end

    private

    def notifications_regex
      @notifications_regex ||= /(#{@normalizers.keys.join('|')})/
    end
  end
end
