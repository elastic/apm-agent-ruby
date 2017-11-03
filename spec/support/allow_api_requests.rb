# frozen_string_literal: true

require 'webmock/rspec'

RSpec.configure do |config|
  config.before :each, allow_api_requests: true do
    # catch all
    @request_stub = stub_request(:post, /localhost:8200/)
  end
end
