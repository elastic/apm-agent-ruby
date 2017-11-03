# frozen_string_literal: true

require 'bundler/setup'
Bundler.require :default

require 'support/allow_api_requests'
require 'support/delegate_matcher'
require 'support/mock_time'
require 'support/with_agent'

require 'elastic_apm'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.backtrace_exclusion_patterns = [%r{/gems/}]

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
