# frozen_string_literal: true

require 'http'

module ElasticAPM
  RSpec.describe 'Spy: HTTP.rb', :intercept do
    after { WebMock.reset! }

    it 'spans http calls' do
      WebMock.stub_request(:get, %r{http://example.com/.*})

      with_agent do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'
    end

    it 'adds traceparent header' do
      req_stub =
        WebMock.stub_request(:get, %r{http://example.com/.*}).with do |req|
          header = req.headers['Elastic-Apm-Traceparent']
          expect(header).to_not be nil
          expect { TraceContext.parse(header) }.to_not raise_error
        end

      with_agent do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      expect(req_stub).to have_been_requested
    end

    it 'adds traceparent header with no span' do
      req_stub = WebMock.stub_request(:get, %r{http://example.com/.*})

      with_agent transaction_max_spans: 0 do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      expect(req_stub).to have_been_requested
    end
  end
end
