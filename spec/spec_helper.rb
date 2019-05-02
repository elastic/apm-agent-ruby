# frozen_string_literal: true

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'

if ENV['INCLUDE_COVERAGE'] == '1'
  require 'simplecov'

  if ENV['CI'] == '1'
    require 'simplecov-cobertura'
    SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
  end

  SimpleCov.start { add_filter('/spec/') }
end

require 'bundler/setup'
Bundler.require :default, 'test'
require 'yarjuf'

require 'webmock/rspec'
WebMock.hide_stubbing_instructions!

Dir['spec/support/*.rb'].each { |file| require "./#{file}" }

require 'elastic-apm'

Concurrent.use_stdlib_logger(Logger::DEBUG)
Thread.abort_on_exception = true

RSpec.configure do |config|
  unless ENV['INCLUDE_SCHEMA_SPECS']
    config.filter_run_excluding(type: 'json_schema')
  end

  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.fail_fast = ENV.fetch('CI', nil) == '1'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

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

def darwin?
  ElasticAPM::Metrics.platform == :darwin
end

def linux?
  ElasticAPM::Metrics.platform == :linux
end

def jruby_92?
  defined?(JRUBY_VERSION) && JRUBY_VERSION =~ /^9\.2/
end
