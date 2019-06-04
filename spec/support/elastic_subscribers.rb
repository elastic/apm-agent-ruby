# frozen_string_literal: true

module ElasticSubscribers
  def elastic_subscribers
    unless defined?(::ActiveSupport) && defined?(ElasticAPM::Subscriber)
      return []
    end

    notifier = ActiveSupport::Notifications.notifier
    subscribers =
      notifier.instance_variable_get(:@subscribers) ||
      notifier.instance_variable_get(:@string_subscribers) # when Rails 6

    subscribers.select do |s|
      s.instance_variable_get(:@delegate).is_a?(ElasticAPM::Subscriber)
    end
  end
end
