# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'elastic_apm/transport/connection'

module ElasticAPM
  module Transport
    RSpec.describe Connection do
      let(:config) { Config.new(http_compression: false) }
      subject { described_class.new(config) }

      after { WebMock.reset! }

      describe '#initialize' do
        it 'is has no active connection' do
          expect(subject.http).to be nil
        end
      end

      describe '#inspect' do
        it 'returns a string with the connection\'s attributes' do
          expect(subject.inspect).to match(
            /ElasticAPM::Transport::Connection.*url:.*closed:.*/
          )
        end
      end

      describe 'write' do
        it 'opens a connection and writes' do
          stub = build_stub(body: /{"msg": "hey!"}/)

          subject.write('{"msg": "hey!"}')
          sleep 0.2

          expect(subject.http.closed?).to be false

          subject.flush
          expect(subject.http.closed?).to be true

          expect(stub).to have_been_requested
        end

        context 'when disable_send' do
          let(:config) { Config.new disable_send: true }

          it 'does nothing' do
            stub = build_stub(body: /{"msg": "hey!"}/)

            subject.write('{"msg": "hey!"}')

            expect(subject.http).to be nil

            subject.flush

            expect(subject.http).to be nil
            expect(stub).to_not have_been_requested
          end
        end
      end

      it 'has a fitting user agent' do
        stub = build_stub(
          headers: {
            'User-Agent' => %r{
              \Aelastic-apm-ruby/(\d+\.)+\d+\s
              http.rb/(\d+\.)+\d+\s
              j?ruby/(\d+\.)+\d+\z
            }x
          }
        )
        subject.write('{}')
        subject.flush
        expect(stub).to have_been_requested
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

      describe 'api key' do
        let(:config) do
          Config.new(api_key: 'a_base64_encoded_string')
        end

        it 'adds an Authorization header if api key provided' do
          stub = build_stub(
            headers: {
              'Authorization' => 'ApiKey a_base64_encoded_string'
            }
          )
          subject.write('{}')
          subject.flush
          expect(stub).to have_been_requested
        end
      end

      context 'max request time' do
        let(:config) { Config.new(api_request_time: '100ms') }

        it 'closes requests when reached' do
          stub = build_stub

          subject.write('{}')

          sleep 0.5

          expect(subject.http.closed?).to be true

          expect(stub).to have_been_requested
        end

        it "doesn't make a scene if already closed" do
          build_stub

          subject.write('{}')
          subject.flush

          expect(subject.http.closed?).to be true

          sleep 0.2
          expect(subject.http.closed?).to be true
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
          sleep 0.2

          expect(subject.http.closed?).to be true

          expect(stub).to have_been_requested
        end

        it "doesn't make a scene if already closed" do
          build_stub

          subject.write('{}')
          subject.flush

          expect(subject.http.closed?).to be true

          sleep 0.2
          expect(subject.http.closed?).to be true
        end

        context 'and gzip off' do
          let(:config) { Config.new(http_compression: false) }
          let(:metadata) do
            Serializers::MetadataSerializer.new(config).build(
              Metadata.new(config)
            )
          end

          before do
            config.api_request_size = "#{metadata.to_json.bytesize + 1}b"
          end

          it 'closes requests when reached' do
            stub = build_stub

            subject.write('{}')

            sleep 0.2
            expect(subject.http.closed?).to be true
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

      describe 'verify_server_cert' do
        let(:config) do
          Config.new(server_url: 'https://self-signed.badssl.com')
        end

        it 'is enabled by default' do
          expect(config.logger)
            .to receive(:error)
            .with(/OpenSSL::SSL::SSLError/)

          WebMock.disable!
          subject.write('')
          subject.flush
          WebMock.enable!
        end

        context 'when disabled' do
          let(:config) do
            Config.new(
              server_url: 'https://self-signed.badssl.com',
              verify_server_cert: false
            )
          end

          it "doesn't complain" do
            expect(config.logger)
              .to_not receive(:error)
              .with(/OpenSSL::SSL::SSLError/)

            WebMock.disable!
            subject.write('')
            subject.flush
            WebMock.enable!
          end
        end
      end
      def build_stub(body: nil, headers: {}, to_return: {}, status: 202, &block)
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
