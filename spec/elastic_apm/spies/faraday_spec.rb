# frozen_string_literal: true

require 'faraday'

module ElasticAPM
  RSpec.describe 'Spy: Faraday', :intercept do
    after do
      ElasticAPM.stop
      WebMock.reset!
    end

    let(:client) do
      Faraday.new(url: 'http://example.com')
    end

    it 'spans http calls' do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start

      ElasticAPM.with_transaction 'Faraday test' do
        client.get('http://example.com/page.html')
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'
      expect(span.type).to eq 'ext'
      expect(span.subtype).to eq 'faraday'
      expect(span.action).to eq 'get'

      ElasticAPM.stop
      WebMock.reset!
    end

    it 'spans http calls with prefix' do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start

      ElasticAPM.with_transaction 'Faraday test' do
        client.get('/page.html')
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'
      expect(span.type).to eq 'ext'
      expect(span.subtype).to eq 'faraday'
      expect(span.action).to eq 'get'

      ElasticAPM.stop
      WebMock.reset!
    end

    it 'spans http calls when url in block' do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start
      client = Faraday.new
      ElasticAPM.with_transaction 'Faraday test' do
        client.get do |req|
          req.url('http://example.com/page.html')
        end
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'
      expect(span.type).to eq 'ext'
      expect(span.subtype).to eq 'faraday'
      expect(span.action).to eq 'get'

      ElasticAPM.stop
      WebMock.reset!
    end

    it 'adds traceparent header' do
      req_stub =
        WebMock.stub_request(:get, %r{http://example.com/.*}).with do |req|
          header = req.headers['Elastic-Apm-Traceparent']
          expect(header).to_not be nil
          expect { TraceContext.parse(header) }.to_not raise_error
        end

      ElasticAPM.start

      ElasticAPM.with_transaction 'Faraday test' do
        client.get('http://example.com/page.html')
      end

      expect(req_stub).to have_been_requested

      ElasticAPM.stop
      WebMock.reset!
    end

    it 'adds traceparent header with no span' do
      req_stub = WebMock.stub_request(:get, %r{http://example.com/.*})

      ElasticAPM.start transaction_max_spans: 0

      ElasticAPM.with_transaction 'Net::HTTP test' do
        client.get('http://example.com/page.html')
      end

      expect(req_stub).to have_been_requested
    end
  end
end
