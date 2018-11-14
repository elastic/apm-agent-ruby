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

          subject.flush
          expect(subject).to_not be_connected

          expect(stub).to have_been_requested
        end
      end

      describe 'secret token' do
        let(:config) { Config.new(secret_token: 'asd') }

        it 'adds an Authorization header if secret token provided' do
          stub = build_stub(headers: { 'Authorization' => 'Bearer asd' })
          subject.write('{}')
          subject.flush
          expect(stub).to have_been_requested
        end
      end

      describe 'handling errors' do
        it 'logs the error' do
          expect(subject).to receive(:error) # log

          errors = { errors: [{ message: 'real big explosion' }] }
          stub = build_stub(to_return: { status: 500, body: errors.to_json })

          subject.write('{}')
          subject.flush

          expect(stub).to have_been_requested.once
        end
      end

      context 'max request time' do
        let(:config) { Config.new(api_request_time: '100ms') }

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
          subject.flush

          expect(subject).to_not be_connected

          sleep 0.2
          expect(subject).to_not be_connected
        end
      end

      context 'max request size' do
        let(:config) { Config.new(api_request_size: '5b') }

        it 'closes requests when reached' do
          stub = build_stub do |req|
            metadata, payload = gunzip(req.body).split("\n")

            expect(metadata).to match('{"metadata":')
            expect(payload).to eq('{}')

            req
          end

          subject.write('{}')

          expect(subject).to_not be_connected

          expect(stub).to have_been_requested
        end

        it "doesn't make a scene if already closed" do
          build_stub

          subject.write('{}')
          subject.flush

          expect(subject).to_not be_connected

          sleep 0.2
          expect(subject).to_not be_connected
        end

        context 'and gzip off' do
          let(:config) { Config.new(http_compression: false) }
          let(:metadata) { Metadata.build(config) }

          before do
            config.api_request_size = metadata.bytesize + 1
          end

          it 'closes requests when reached' do
            stub = build_stub

            subject.write('{}')

            sleep 0.2
            expect(subject).to_not be_connected

            expect(stub).to have_been_requested
          end
        end
      end

      context 'http compression' do
        let(:config) { Config.new }

        it 'compresses the payload' do
          stub = build_stub(
            headers: { 'Content-Encoding' => 'gzip' }
          ) do |req|
            metadata, payload = gunzip(req.body).split("\n")

            expect(metadata).to match('{"metadata":')
            expect(payload).to eq('{}')

            req
          end

          subject.write('{}')
          subject.flush

          expect(stub).to have_been_requested
        end
      end

      # rubocop:disable Metrics/MethodLength
      def build_stub(body: nil, headers: {}, to_return: {}, &block)
        opts = {
          headers: {
            'Transfer-Encoding' => 'chunked',
            'Content-Type' => 'application/x-ndjson'
          }.merge(headers)
        }

        opts[:body] = body if body

        WebMock
          .stub_request(:post, 'http://localhost:8200/intake/v2/events')
          .with(**opts, &block)
          .to_return(to_return.merge(status: 202) { |_, old, _| old })
      end
      # rubocop:enable Metrics/MethodLength

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
