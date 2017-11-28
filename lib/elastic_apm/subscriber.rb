# frozen_string_literal: true

require 'active_support/notifications'
require 'elastic_apm/normalizers'

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

    Notification = Struct.new(:id, :span)

    def start(name, id, payload)
      # debug "AS::Notification#start:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      normalized = @normalizers.normalize(transaction, name, payload)

      span = normalized == :skip ? nil : transaction.span(*normalized)

      transaction.notifications << Notification.new(id, span)
    end

    def finish(_name, id, _payload)
      # debug "AS::Notification#finish:#{name}:#{id}"
      return unless (transaction = @agent.current_transaction)

      while (notification = transaction.notifications.pop)
        next unless notification.id == id

        if (span = notification.span)
          span.done
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
