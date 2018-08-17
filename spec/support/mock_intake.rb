# frozen_string_literal: true

require 'json'
require 'timeout'

class MockAPMServer
  class << self
    def requests
      @requests ||= []
    end

    def transactions
      @transactions ||= []
    end

    def spans
      @spans ||= []
    end

    def errors
      @errors ||= []
    end

    def clear!
      @requests = []
      @transactions = []
      @spans = []
      @errors = []
    end

    def call(env)
      request = Rack::Request.new(env)
      body = request.body.read

      requests << body

      body.split("\n").map do |line|
        JSON.parse(line.strip)
      end.compact.each(&method(:catalog))

      [200, { 'Content-Type' => 'application/json' }, ['ok']]
    end

    def catalog(obj)
      case obj.keys.first
      when 'transaction' then transactions << obj.values.first
      when 'span' then spans << obj.values.first
      when 'error' then errors << obj.values.first
      end
    end
  end
end

RSpec.configure do |config|
  config.before :each, :mock_intake do
    MockAPMServer.clear!

    @request_stub =
      WebMock.stub_request(
        :any,
        %r{^http://localhost:8200/v2/intake.*}
      ).to_rack(MockAPMServer)
  end

  config.after :each, :mock_intake do
    WebMock.reset!
    @request_stub = nil
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  # rubocop:disable Style/MultilineIfModifier
  def wait_for_requests_to_finish(request_count)
    unless @request_stub
      raise 'No request stub – did you forget :mock_intake?'
    end

    Timeout.timeout(5) do
      loop do
        missing = request_count - MockAPMServer.requests.length
        next if missing > 0

        unless missing == 0
          puts format(
            'Expected %d requests. Got %d',
            request_count,
            MockAPMServer.requests.length
          )
        end

        break true
      end
    end
  rescue Timeout::Error
    puts format('Died waiting for %d requests', request_count)
    puts "--- Received: ---\n#{MockAPMServer.requests.inspect}"
    raise
  end unless defined?(wait_for_requests_to_finish)
  # rubocop:enable Style/MultilineIfModifier
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end
