# frozen_string_literal: true

require 'http'

module ElasticAPM
  RSpec.describe 'Spy: HTTP.rb', :intercept do
    after { WebMock.reset! }

    context 'http calls' do
      before do
        WebMock.stub_request(:get, %r{http://example.com/.*})
        with_agent do
          ElasticAPM.with_transaction 'HTTP test' do
            HTTP.get('http://example.com')
          end
        end
      end

      let(:span) do
        @intercepted.spans[0]
      end

      it 'spans the calls' do
        expect(span).to_not be nil
        expect(span.name).to eq 'GET example.com'
      end
    end

    context 'traceparent header' do
      before do
        req_stub
        with_agent do
          ElasticAPM.with_transaction 'HTTP test' do
            HTTP.get('http://example.com')
          end
        end
      end

      let(:req_stub) do
        WebMock.stub_request(:get, %r{http://example.com/.*}).with do |req|
          header = req.headers['Elastic-Apm-Traceparent']
          expect(header).to_not be nil
          expect { TraceContext.parse(header) }.to_not raise_error
        end
      end

      it 'adds the header' do
        expect(req_stub).to have_been_requested
      end
    end

    context 'traceparent header with no span' do
      before do
        req_stub
        with_agent transaction_max_spans: 0 do
          ElasticAPM.with_transaction 'Net::HTTP test' do
            HTTP.get('http://example.com')
          end
        end
      end

      let(:req_stub) do
        WebMock.stub_request(:get, %r{http://example.com/.*})
      end

      it 'adds the header' do
        expect(req_stub).to have_been_requested
      end
    end
  end
end
