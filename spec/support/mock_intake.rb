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

  # rubocop:disable Metrics/MethodLength
  def parse_request_body(request)
    encoding = request.env['HTTP_CONTENT_ENCODING']

    body =
      if encoding =~ /gzip/
        gunzip(request.body.read)
      else
        request.body.read
      end

    body
      .split("\n")
      .map do |json|
        JSON.parse(json)
      end
  end
  # rubocop:enable Metrics/MethodLength

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
  def wait_for_requests_to_finish(request_count)
    raise 'No request stub – did you forget :mock_intake?' unless @request_stub

    Timeout.timeout(5) do
      loop do
        missing = request_count - @mock_intake.requests.length
        next if missing > 0

        unless missing == 0
          puts format(
            'Expected %d requests. Got %d',
            request_count,
            @mock_intake.requests.length
          )
        end

        break true
      end
    end
  rescue Timeout::Error
    puts format('Died waiting for %d requests', request_count)
    puts "--- Received: ---\n#{@mock_intake.requests.inspect}"
    raise
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
