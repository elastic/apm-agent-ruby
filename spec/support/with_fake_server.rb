# frozen_string_literal: true

require 'json'

RSpec.configure do |config|
  class FakeServer < Sinatra::Base
    class << self
      attr_reader :requests

      def clear!
        @requests = []
      end
    end

    before do
      content_type 'application/json'
    end

    post '/v1/transactions' do
      self.class.requests << JSON.parse(request.body.read)
      '"ok"'
    end
  end

  config.before :each, with_fake_server: true do
    @request_stub = WebMock.stub_request(:any, /localhost:8200/).to_rack(FakeServer)
    FakeServer.clear!
  end
end
