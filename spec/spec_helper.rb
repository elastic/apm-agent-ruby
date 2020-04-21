# frozen_string_literal: true

if ENV["TEST_MATRIX"]
  require 'simplecov'
  SimpleCov.coverage_dir("coverage/matrix_results/" + ENV["TEST_MATRIX"])
  SimpleCov.start { add_filter('/spec/') }
end

ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'

begin
  require 'bootsnap'
  Bootsnap.setup(cache_dir: "#{ENV.fetch('VENDOR_PATH', 'tmp')}/bootsnap")
rescue LoadError
  # Bootsnap depends on ActiveSupport, but as AS heavily modifies stdlib
  # we still want to test Sinatra without it
end

require 'bundler/setup'
Bundler.require :default, 'test'
require 'yarjuf'

Dir['spec/support/*.rb'].each { |file| require "./#{file}" }

require 'elastic-apm'

Concurrent.use_stdlib_logger(Logger::DEBUG)
Thread.abort_on_exception = true

SpecLogger = StringIO.new

module RailsTestHelpers
  def self.included(_kls)
    Rails::Application.class_eval do
      def configure_rails_for_test
        config.secret_key_base = '__secret_key_base'
        config.consider_all_requests_local = false
        config.eager_load = false

        config.elastic_apm.api_request_time = '200ms'
        config.elastic_apm.disable_start_message = true

        return unless defined?(ActionView::Railtie::NULL_OPTION)

        # Silence deprecation warning
        config.action_view.finalize_compiled_template_methods =
          ActionView::Railtie::NULL_OPTION
      end
    end
  end

  def self.setup_rails_test_config(config)
    config.secret_key_base = '__secret_key_base'
    config.consider_all_requests_local = false
    config.eager_load = false
    if config.respond_to?(:action_mailer)
      config.action_mailer.perform_deliveries = false
    end
    config.logger = Logger.new(SpecLogger)

    # Silence deprecation warning
    return unless defined?(ActionView::Railtie::NULL_OPTION)
    config.action_view.finalize_compiled_template_methods =
      ActionView::Railtie::NULL_OPTION
  end
end

RSpec.configure do |config|
  config.order = :random

  config.include ExceptionHelpers
  config.include WithAgent
  config.include PlatformHelpers
  config.include ElasticSubscribers
  config.include RailsTestHelpers if defined?(Rails)

  if config.files_to_run.one?
    config.default_formatter = 'documentation'
  end

  unless ENV['INCLUDE_SCHEMA_SPECS']
    config.filter_run_excluding(type: 'json_schema')
  end

  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.backtrace_inclusion_patterns = [/elastic_apm/]

  config.before(:each) do |example|
    if ElasticAPM.running? && !example.metadata[:allow_running_agent]
      raise 'Previous example left an agent running'
    end
  end

  config.after(:each) do |example|
    if ElasticAPM.running? && !example.metadata[:allow_running_agent]
      raise 'This example left an agent running'
    end

    if elastic_subscribers.any? &&
       !example.metadata[:allow_running_agent]
      raise 'someone leaked subscription'
    end
  end

  config.after(:each, spec_logger: true) do |example|
    SpecLogger.rewind
    next unless example.exception

    puts 'Example failed, dumping log:'
    puts SpecLogger.read
  end
end

RSpec.shared_context 'stubbed_central_config' do
  before(:all) do
    WebMock.stub_request(
      :get, %r{^http://localhost:8200/config/v1/agents/?$}
    ).to_return(body: '{}')
  end

  after(:all) do
    WebMock.reset!
  end
end
