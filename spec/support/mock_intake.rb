# frozen_string_literal: true

require 'json'
require 'timeout'
require 'rack/chunked'

class Intake
  def initialize
    @requests = []
    @transactions = []
    @spans = []
    @errors = []
    @metadatas = []
  end

  attr_reader :requests, :transactions, :spans, :errors, :metadatas

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
    @mock_intake = Intake.new

    @request_stub =
      WebMock.stub_request(
        :any,
        %r{^http://localhost:8200/intake/v2/events/?$}
      ).to_rack(@mock_intake)
  end

  config.after :each, :mock_intake do
    WebMock.reset!
    @request_stub = @mock_intake = nil
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def wait_for(expected)
    raise 'No request stub – did you forget :mock_intake?' unless @request_stub

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
