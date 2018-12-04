# frozen_string_literal: true

require 'http'

module ElasticAPM
  RSpec.describe 'Spy: HTTP.rb' do
    it 'spans http calls', :intercept do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start

      ElasticAPM.with_transaction 'HTTP test' do
        HTTP.get('http://example.com')
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'

      ElasticAPM.stop
      WebMock.reset!
    end

    it 'adds traceparent header' do
      req_stub =
        WebMock.stub_request(:get, %r{http://example.com/.*}).with do |req|
          header = req.headers['Elastic-Apm-Traceparent']
          expect(header).to_not be nil
          expect { Traceparent.parse(header) }.to_not raise_error
        end

      ElasticAPM.start

      ElasticAPM.with_transaction 'HTTP test' do
        HTTP.get('http://example.com')
      end

      expect(req_stub).to have_been_requested

      ElasticAPM.stop
      WebMock.reset!
    end

    it 'adds traceparent header with no span' do
      req_stub = WebMock.stub_request(:get, %r{http://example.com/.*})

      ElasticAPM.start transaction_max_spans: 0

      ElasticAPM.with_transaction 'HTTP test' do
        HTTP.get('http://example.com')
      end

      expect(req_stub).to have_been_requested

      ElasticAPM.stop
      WebMock.reset!
    end
  end
end
