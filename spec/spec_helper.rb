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
  config.include ExceptionHelpers
  config.include WithAgent
  config.include PlatformHelpers
  config.include ElasticSubscribers

  if config.files_to_run.one?
    config.default_formatter = 'documentation'
  end

  unless ENV['INCLUDE_SCHEMA_SPECS']
    config.filter_run_excluding(type: 'json_schema')
  end

  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.backtrace_inclusion_patterns = [/elastic_apm/]

  config.after(:each) do |example|
    if elastic_subscribers.any? &&
       !example.metadata[:allow_leaking_subscriptions] &&
       example.execution_result.status == :passed

      raise 'someone leaked subscription'
    end
  end
end
