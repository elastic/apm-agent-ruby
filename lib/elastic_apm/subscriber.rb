# frozen_string_literal: true

require 'active_support/notifications'

module ElasticAPM
  # @api private
  class Subscriber
    include Log

    def initialize(agent)
      @agent = agent
      @config = agent.config
      @normalizers = Normalizers.build(config)
    end

    attr_reader :config

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

    Notification = Struct.new(:id, :trace)

    def start(name, id, payload)
      # debug "AS::Notification#start:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      normalized = @normalizers.normalize(transaction, name, payload)

      trace = normalized == :skip ? nil : transaction.trace(*normalized)

      transaction.notifications << Notification.new(id, trace)
    end

    def finish(_name, id, _payload)
      # debug "AS::Notification#finish:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      while (notification = transaction.notifications.pop)
        next unless notification.id == id

        if (trace = notification.trace)
          trace.done
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
