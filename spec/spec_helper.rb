# frozen_string_literal: true

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
ENV['ELASTIC_APM_ENABLED_ENVIRONMENTS'] = 'test'

require 'bundler/setup'
Bundler.require :default, 'test'

require 'webmock/rspec'
WebMock.hide_stubbing_instructions!

require 'support/delegate_matcher'
require 'support/match_json_schema_matcher'
require 'support/mock_time'
require 'support/with_fake_server'

require 'elastic-apm'

Thread.abort_on_exception = true

RSpec.configure do |config|
  unless ENV['INCLUDE_SCHEMA_SPECS']
    config.filter_run_excluding(type: 'json_schema')
  end

  config.fail_fast = true unless ENV['CI']

  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  # config.backtrace_exclusion_patterns = [%r{/(gems|bundler)/}]

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

  config.after(:each) do |example|
    if elastic_subscribers.any? &&
       !example.metadata[:allow_leaking_subscriptions] &&
       example.execution_result.status == :passed
      raise 'someone leaked subscription'
    end
  end
end

def actual_exception
  1 / 0
rescue => e # rubocop:disable Style/RescueStandardError
  e
end
