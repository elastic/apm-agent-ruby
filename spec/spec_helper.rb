# frozen_string_literal: true

require 'bundler/setup'
Bundler.require :default

require 'support/delegate_matcher'
require 'support/mock_time'
require 'support/with_fake_server'

require 'elastic-apm'

WebMock.enable!

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.backtrace_exclusion_patterns = [%r{/(gems|bundler)/}]

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def elastic_subscribers
    ActiveSupport::Notifications
      .notifier.instance_variable_get(:@subscribers)
      .select do |s|
        s.instance_variable_get(:@delegate).is_a?(ElasticAPM::Subscriber)
      end
  end

  config.after(:each) do
    raise 'someone leaked subscription' if elastic_subscribers.any?
  end
end
