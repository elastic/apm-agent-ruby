# frozen_string_literal: true

require 'json'

RSpec.configure do |config|
  class FakeServer
    class << self
      attr_reader :requests

      def clear!
        @requests = []
      end
    end

    def call(env)
      request = Rack::Request.new(env)
      self.class.requests << JSON.parse(request.body.read)

      [200, { 'Content-Type' => 'application/json' }, ['ok']]
    end
  end

  config.before :each, with_fake_server: true do
    @request_stub =
      WebMock.stub_request(:any, /localhost:8200/).to_rack(FakeServer.new)
    FakeServer.clear!
  end
end
