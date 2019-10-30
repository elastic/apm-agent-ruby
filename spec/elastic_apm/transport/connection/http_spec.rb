# frozen_string_literal: true

require 'elastic_apm/transport/connection'

module ElasticAPM
  module Transport
    RSpec.describe Connection::Http do
      let(:config) { Config.new(http_compression: false) }

      let(:metadata) do
        JSON.fast_generate(metadata: { service_name: 'Test' })
      end

      let(:url) { 'http://localhost:8200/intake/v2/events' }

      let(:headers) do
        {
          'Transfer-Encoding' => 'chunked',
          'Content-Type' => 'application/x-ndjson'
        }
      end

      describe '#initialize' do
        subject { described_class.open(config, url) }

        it 'is has no active connection' do
          expect(subject.closed?).to be false
        end
      end

      describe 'write and close' do
        subject { described_class.open(config, url) }

        it 'sends metadata' do
          stub = build_stub(body: /metadata/, headers: headers)

          subject.write(metadata)
          subject.write('{"msg": "hey!"}')
          sleep 0.2

          subject.close(:api_request_size)
          expect(stub).to have_been_requested
        end

        it 'opens a connection and writes' do
          stub = build_stub(body: /{"msg": "hey!"}/, headers: headers)

          subject.write('{"msg": "hey!"}')
          sleep 0.2

          subject.close(:api_request_size)
          expect(stub).to have_been_requested
        end

        it 'closes the connection on close' do
          stub = build_stub(body: /{"msg": "hey!"}/, headers: headers)

          subject.write('{"msg": "hey!"}')
          sleep 0.2

          expect(subject.closed?).to be false
          subject.close(:api_request_size)
          expect(subject.closed?).to be true
          expect(stub).to have_been_requested
        end

        it "doesn't make a scene if already closed" do
          build_stub(headers: headers)

          subject.write('{}')
          subject.close(:api_request_size)
          expect(subject.closed?).to be true

          subject.close(:api_request_size)
          expect(subject.closed?).to be true
        end
      end

      context 'http compression' do
        let(:config) { Config.new }

        subject { described_class.open(config, url) }

        it 'compresses the payload' do
          stub = build_stub(
            headers: headers.merge!('Content-Encoding' => 'gzip')
          ) do |req|
            metadata, payload = gunzip(req.body).split("\n")

            expect(metadata).to match('{"metadata":')
            expect(payload).to eq('{}')

            req
          end

          subject.write(metadata)
          subject.write('{}')
          subject.close(:api_request_size)

          expect(stub).to have_been_requested
        end
      end

      def build_stub(body: nil, headers: {}, to_return: {}, status: 202, &block)
        opts = { headers: headers }
        opts[:body] = body if body

        WebMock
          .stub_request(:post, 'http://localhost:8200/intake/v2/events')
          .with(**opts, &block)
          .to_return(to_return.merge(status: status) { |_, old, _| old })
      end

      def gunzip(string)
        sio = StringIO.new(string)
        gz = Zlib::GzipReader.new(sio, encoding: Encoding::ASCII_8BIT)
        gz.read
      ensure
        gz&.close
      end
    end
  end
end
