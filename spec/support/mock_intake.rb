# frozen_string_literal: true

require 'json'
require 'timeout'
require 'rack/chunked'

class MockIntake
  def initialize
    clear!
  end

  attr_reader :requests, :transactions, :spans, :errors, :metadatas

  def self.instance
    @instance ||= new
  end

  class << self
    extend Forwardable

    def_delegator :instance, :stub!
    def_delegator :instance, :stubbed?
    def_delegator :instance, :clear!
    def_delegator :instance, :reset!
  end

  def stub!
    @request_stub =
      WebMock.stub_request(
        :any, %r{^http://localhost:8200/intake/v2/events/?$}
      ).to_rack(self)
  end

  def stubbed?
    !!@request_stub
  end

  def clear!
    @requests = []
    @transactions = []
    @spans = []
    @errors = []
    @metadatas = []
  end

  def reset!
    clear!
    WebMock.reset!
    @request_stub = nil
  end

  def call(env)
    request = Rack::Request.new(env)
    @requests << request

    metadata, *rest = parse_request_body(request)

    metadatas << metadata.values.first

    rest.each do |obj|
      catalog obj
    end

    [202, {}, ['ok']]
  end

  def parse_request_body(request)
    body =
      if request.env['HTTP_CONTENT_ENCODING'] =~ /gzip/
        gunzip(request.body.read)
      else
        request.body.read
      end

    body
      .split("\n")
      .map { |json| JSON.parse(json) }
  end

  private

  def gunzip(string)
    sio = StringIO.new(string)
    gz = Zlib::GzipReader.new(sio, encoding: Encoding::ASCII_8BIT)
    gz.read
  ensure
    gz&.close
  end

  def catalog(obj)
    case obj.keys.first
    when 'transaction' then transactions << obj.values.first
    when 'span' then spans << obj.values.first
    when 'error' then errors << obj.values.first
    end
  end
end

RSpec.configure do |config|
  config.before :each, :mock_intake do
    MockIntake.instance.stub! unless MockIntake.instance.stubbed?
    @mock_intake = MockIntake.instance
  end

  config.after :each, :mock_intake do
    MockIntake.instance.reset!
    @mock_intake = nil
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def wait_for(expected)
    unless MockIntake.stubbed?
      raise 'Not stubbed – did you forget :mock_intake?'
    end

    Timeout.timeout(5) do
      loop do
        sleep 0.01

        missing = expected.reduce(0) do |total, (kind, count)|
          total + (count - @mock_intake.send(kind).length)
        end

        next if missing > 0

        unless missing == 0
          puts format(
            'Expected %s. Got %s',
            expected,
            missing
          )
          print_received
        end

        break true
      end
    end
  rescue Timeout::Error
    puts format('Died waiting for %s', expected)
    puts '--- Received: ---'
    print_received
    raise
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def print_received
    pp(
      transactions: @mock_intake.transactions.map { |o| o['name'] },
      spans: @mock_intake.spans.map { |o| o['name'] },
      errors: @mock_intake.errors.map { |o| o['culprit'] },
      metadatas: @mock_intake.metadatas.count
    )
  end
end
