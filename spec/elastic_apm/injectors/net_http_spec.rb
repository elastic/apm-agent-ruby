# frozen_string_literal: true

require 'spec_helper'

require 'elastic_apm/injectors/net_http'

module ElasticAPM
  RSpec.describe Injectors::NetHTTPInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['net/http'] || # when missing
        Injectors.installed['Net::HTTP'] # when present

      expect(registration.injector).to be_a described_class
    end

    it 'traces http calls' do
      ElasticAPM.start Config.new(
        enabled_injectors: %w[net_http]
      )

      WebMock.stub_request :get, 'http://example.com:80'

      transaction = ElasticAPM.transaction 'Net::HTTP test'

      Net::HTTP.start('example.com') do |http|
        http.get '/'
      end

      expect(WebMock).to have_requested(:get, 'http://example.com')
      expect(transaction.traces.length).to be 1

      http_trace = transaction.traces.last
      expect(http_trace.name).to eq 'GET example.com'
      expect(http_trace.extra).to eq(
        scheme: 'http',
        port: 80,
        path: '/'
      )

      ElasticAPM.stop
    end

    it 'passes through when not tracing' do
      WebMock.stub_request :get, 'http://example.com:80'

      Net::HTTP.start('example.com') do |http|
        http.get '/'
      end

      expect(WebMock).to have_requested(:get, 'http://example.com')
    end
  end
end
