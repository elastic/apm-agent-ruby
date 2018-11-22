# frozen_string_literal: true

require 'faraday'

module ElasticAPM
  RSpec.describe 'Spy: Faraday' do
    let(:client) do
      Faraday.new(url: 'http://example.com')
    end

    it 'spans http calls', :intercept do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start

      ElasticAPM.with_transaction 'Faraday test' do
        client.get('http://example.com/page.html')
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'
      expect(span.type).to eq 'ext.faraday.get'

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

      ElasticAPM.with_transaction 'Faraday test' do
        client.get('http://example.com/page.html')
      end

      expect(req_stub).to have_been_requested

      ElasticAPM.stop
      WebMock.reset!
    end
  end
end
