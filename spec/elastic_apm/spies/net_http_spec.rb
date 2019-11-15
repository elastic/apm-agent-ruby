# frozen_string_literal: true

require 'net/http'

module ElasticAPM
  RSpec.describe 'Spy: NetHTTP', :intercept do
    after { WebMock.reset! }

    context 'http calls' do
      before do
        WebMock.stub_request(:get, %r{http://example.com/.*})
        with_agent do
          ElasticAPM.with_transaction 'Net::HTTP test' do
            Net::HTTP.start('example.com') do |http|
              http.get '/'
            end
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
          ElasticAPM.with_transaction 'Net::HTTP test' do
            Net::HTTP.start('example.com') do |http|
              http.get '/'
            end
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
          Net::HTTP.start('example.com') do |http|
            http.get '/'
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

    context 'disabled spy' do
      before do
        WebMock.stub_request(:any, %r{http://example.com/.*})

        with_agent do
          expect(ElasticAPM::Spies::NetHTTPSpy).to_not be_disabled

          ElasticAPM.with_transaction 'Net::HTTP test' do
            ElasticAPM::Spies::NetHTTPSpy.disable_in do
              Net::HTTP.start('example.com') do |http|
                http.get '/'
              end
            end

            Net::HTTP.start('example.com') do |http|
              http.post '/', 'a=1'
            end
          end
        end
      end

      let(:span) do
        @intercepted.spans[0]
      end

      it 'doesn\'t spy' do
        expect(@intercepted.transactions.length).to be 1
        expect(@intercepted.spans.length).to be 1
        expect(span.name).to eq 'POST example.com'
        expect(span.type).to eq 'ext'
        expect(span.subtype).to eq 'net_http'
        expect(span.action).to eq 'POST'
      end
    end
  end
end
