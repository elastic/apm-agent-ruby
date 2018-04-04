# frozen_string_literal: true

require 'json'
require 'timeout'

class FakeServer
  class << self
    MUTEX = Mutex.new

    def requests
      return @requests if @requests

      MUTEX.lock { clear! }
    end

    def clear!
      @requests = []
    end

    def call(env)
      request = Rack::Request.new(env)
      requests << JSON.parse(request.body.read)

      [200, { 'Content-Type' => 'application/json' }, ['ok']]
    end
  end
end

RSpec.configure do |config|
  config.before :each, :with_fake_server do
    FakeServer.clear!
    @request_stub = WebMock.stub_request(:any, /.*/).to_rack(FakeServer)
  end

  config.after :each, :with_fake_server do
    WebMock.reset!
    @request_stub = nil
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  # rubocop:disable Style/MultilineIfModifier
  def wait_for_requests_to_finish(request_count)
    unless @request_stub
      raise 'No request stub – did you forget :with_fake_server?'
    end

    Timeout.timeout(5) do
      loop do
        missing = request_count - FakeServer.requests.length
        next if missing > 0

        unless missing == 0
          puts format(
            'Expected %d requests. Got %d',
            request_count,
            FakeServer.requests.length
          )
        end

        break true
      end
    end
  rescue Timeout::Error
    puts format('Died waiting for %d requests', request_count)
    puts "--- Received: ---\n#{FakeServer.requests.inspect}"
    raise
  end unless defined?(wait_for_requests_to_finish)
  # rubocop:enable Style/MultilineIfModifier
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end
