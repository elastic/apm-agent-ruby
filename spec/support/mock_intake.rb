# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'json'
require 'timeout'
begin
  if ::Rack.release >= '3.1'
    require 'rack'
  end
rescue NoMethodError
  require 'rack/chunked'
end

class MockIntake
  def initialize
    clear!

    @span_types = JSON.parse(File.read('./spec/fixtures/span_types.json'))
  end

  attr_reader(
    :errors,
    :metadatas,
    :metricsets,
    :requests,
    :spans,
    :transactions
  )

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
    @cloud_provider_stubs = {
      aws: WebMock.stub_request(
        :get, ElasticAPM::Metadata::CloudInfo::AWS_URI
      ).to_timeout,
      gcp: WebMock.stub_request(
        :get, ElasticAPM::Metadata::CloudInfo::GCP_URI
      ).to_timeout,
      azure: WebMock.stub_request(
        :get, ElasticAPM::Metadata::CloudInfo::AZURE_URI
      ).to_timeout
    }

    @central_config_stub =
      WebMock.stub_request(
        :get, %r{^http://localhost:8200/config/v1/agents/?$}
      ).to_return(body: '{}')

    @server_version_stub =
      WebMock.stub_request(:get, %r{^http://localhost:8200/$}).
      to_return(body: '{"version":8.0}')

    @request_stub =
      WebMock.stub_request(
        :post, %r{^http://localhost:8200/intake/v2/events/?$}
      ).to_rack(self)

    self
  end

  def stubbed?
    !!@request_stub && @central_config_stub
  end

  def clear!
    @requests = []

    @errors = []
    @metadatas = []
    @metricsets = []
    @spans = []
    @transactions = []
  end

  def reset!
    clear!
    @request_stub = nil
    @central_config_stub = nil
    @cloud_provider_stubs = nil
    @server_version_stub = nil
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
      if request.env['HTTP_CONTENT_ENCODING'].include?('gzip')
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
    when 'error' then errors << obj.values.first
    when 'metricset' then metricsets << obj.values.first
    when 'span'
      validate_span!(obj.values.first)
      spans << obj.values.first
    end
  end

  def validate_span!(span)
    type, subtype, _action = span['type'].split('.')

    begin
      info = @span_types.fetch(type)
    rescue KeyError
      puts "Unknown span.type `#{type}'\nPossible types: #{@span_types.keys.join(', ')}"
      pp span
      raise
    end

    return unless (allowed_subtypes = info['subtypes'])

    if !info['optional_subtype'] && !subtype
      msg = "span.subtype missing when required for type `#{type}',\n" \
        "Possible subtypes: #{allowed_subtypes}"
      puts msg # print because errors are swallowed
      pp span
      raise msg
    end

    allowed_subtypes.fetch(subtype)
  rescue KeyError => e
    puts "Unknown span.subtype `#{subtype.inspect}'\n" \
      "Possible subtypes: #{allowed_subtypes}"
    pp span
    puts e # print because errors are swallowed
    raise
  end

  module WaitFor
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def wait_for(timeout: 5, **expected)
      if expected.empty? && !block_given?
        raise ArgumentError, 'Either args or block required'
      end

      unless MockIntake.stubbed?
        raise 'Not stubbed – did you forget :mock_intake?'
      end

      Timeout.timeout(timeout) do
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

          if block_given?
            next unless yield(@mock_intake)
          end

          break true
        end
      end
    rescue Timeout::Error
      puts format('Died waiting for %s', block_given? ? 'block' : expected)
      puts '--- Received: ---'
      print_received
      raise
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def print_received
      pp(
        transactions: @mock_intake.transactions.map { |o| o['name'] },
        spans: @mock_intake.spans.map { |o| o['name'] },
        errors: @mock_intake.errors.map { |o| o['culprit'] },
        metricsets: @mock_intake.metricsets,
        metadatas: @mock_intake.metadatas.count
      )
    end
  end
end

RSpec.configure do |config|
  config.before :each, :mock_intake do
    MockIntake.stub! unless MockIntake.stubbed?
    @mock_intake = MockIntake.instance
  end

  config.after :each, :mock_intake do
    MockIntake.reset!
    @mock_intake = nil
  end

  config.include MockIntake::WaitFor, :mock_intake
end
