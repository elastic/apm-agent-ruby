# frozen_string_literal: true

require 'webmock'
require 'webmock/rspec/matchers'

WebMock.hide_stubbing_instructions!

# We want everything from webmock/rspec except resetting after each example
RSpec.configure do |config|
  config.include WebMock::API
  config.include WebMock::Matchers

  config.before(:suite) { WebMock.enable! }
  config.after(:suite) { WebMock.disable! }
end
