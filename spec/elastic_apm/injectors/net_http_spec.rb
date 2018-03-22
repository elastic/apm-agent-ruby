# frozen_string_literal: true

require 'spec_helper'
require 'net/http'

require 'elastic_apm/injectors/net_http'

module ElasticAPM
  RSpec.describe Injectors::NetHTTPInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['net/http'] || # when missing
        Injectors.installed['Net::HTTP'] # when present

      expect(registration.injector).to be_a described_class
    end

    it 'spans http calls' do
      ElasticAPM.start Config.new(
        enabled_injectors: %w[net_http]
      )

      WebMock.disable!

      transaction = ElasticAPM.transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end.submit 200

      WebMock.enable!
      expect(transaction.spans.length).to be 1

      http_span = transaction.spans.last
      expect(http_span.name).to eq 'GET example.com'

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
