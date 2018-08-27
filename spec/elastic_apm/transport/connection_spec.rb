# frozen_string_literal: true

require 'elastic_apm/transport/connection'

module ElasticAPM
  module Transport
    RSpec.describe Connection do
      let(:config) { Config.new(http_compression: false) }
      subject { described_class.new config }

      describe '#initialize' do
        it { should_not be_connected }
      end

      describe 'write' do
        it 'opens a connection and writes' do
          stub = build_stub(body: /{"msg": "hey!"}/)

          subject.write('{"msg": "hey!"}')
          expect(subject).to be_connected

          subject.close!
          expect(subject).to_not be_connected

          expect(stub).to have_been_requested
        end
      end

      context 'when given max request time' do
        let(:config) { Config.new(api_request_time: 0.1) }

        it 'closes requests when reached' do
          stub = build_stub

          subject.write('{}')

          sleep 0.2
          expect(subject).to_not be_connected

          expect(stub).to have_been_requested
        end

        it "doesn't make a scene if already closed" do
          build_stub

          subject.write('{}')
          subject.close!

          expect(subject).to_not be_connected

          sleep 0.2
          expect(subject).to_not be_connected
        end
      end

      context 'http compression' do
        let(:config) { Config.new(http_compression: true) }

        it 'compresses the payload' do
          stub = build_stub(
            headers: { 'Content-Encoding' => 'gzip' }
          ) do |req|
            metadata, payload = Zlib.gunzip(req.body).split("\n")

            expect(metadata).to match('{"metadata":')
            expect(payload).to eq('{}')

            req
          end

          subject.write('{}')
          subject.close!

          expect(stub).to have_been_requested
        end
      end

      def build_stub(body: nil, headers: {}, &block)
        opts = {
          headers: {
            'Transfer-Encoding' => 'chunked',
            'Content-Type' => 'application/x-ndjson'
          }.merge(headers)
        }

        opts[:body] = body if body

        WebMock
          .stub_request(:post, 'http://localhost:8200/v2/intake')
          .with(**opts, &block)
      end
    end
  end
end
