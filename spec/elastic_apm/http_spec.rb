# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Http do
    describe '#post', :with_fake_server do
      let(:config) { {} }

      subject do
        Http.new Config.new({
          service_name: 'app-1',
          environment: 'test'
        }.merge(config))
      end

      it 'aborts when payload is nil' do
        subject.filters.add :niller, ->(_payload) { nil }
        subject.post('/v1/transactions', never_me: 1)
        expect(WebMock).to_not have_requested(:any, /.*/)
      end

      it 'sets the appropriate headers' do
        subject.post('/v1/transactions', things: 1)

        expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => "elastic-apm/ruby #{VERSION}",
            'Content-Length' => /\d{1,}/
          }
        )
      end

      it 'includes bearer token if provided' do
        http = Http.new Config.new(secret_token: 'abc123')
        http.post('/v1/transactions')

        expect(WebMock).to have_requested(:post, %r{/v1/transactions})
          .with(headers: { 'Authorization' => 'Bearer abc123' })
      end

      it 'merges payload with system and service metadata' do
        subject.post('/v1/transactions', transactions: [{ id: 1 }])

        payload, = FakeServer.requests
        expect(payload['system']).to be_a Hash
        expect(payload['service']).to be_a Hash
      end

      it 'filters sensitive data' do
        subject.post(
          '/v1/transactions', transactions: [
            { id: 1, context: { request: { headers: { ApiKey: 'OH NO!' } } } }
          ]
        )

        payload, = FakeServer.requests
        headers =
          payload.dig('transactions', 0, 'context', 'request', 'headers')
        expect(headers['ApiKey']).to eq '[FILTERED]'
      end

      context 'compression' do
        before do
          subject.post('/v1/transactions', things: 1)
        end

        context 'with payloads under the minimum compression size' do
          let(:config) do
            { compression_minimum_size: 1_024_000 }
          end

          it "doesn't compress the payload" do
            expect(WebMock).to_not have_requested(:post, %r{/v1/transactions})
              .with(headers: { 'Content-Encoding' => 'deflate' })
          end
        end

        context 'with payloads over the minimum compression size' do
          let(:config) do
            { compression_minimum_size: 1 }
          end

          it 'compresses the payload' do
            expect(WebMock).to have_requested(:post, %r{/v1/transactions})
              .with(headers: { 'Content-Encoding' => 'deflate' })
          end

          context 'and compression disabled' do
            let(:config) do
              { compression_minimum_size: 1, http_compression: false }
            end

            it "doesn't compress the payload" do
              expect(WebMock).to_not have_requested(:post, %r{/v1/transactions})
                .with(headers: { 'Content-Encoding' => 'deflate' })
            end
          end
        end
      end
    end

    context 'verifying certs' do
      it 'explodes on bad cert' do
        http = Http.new Config.new(server_url: 'https://expired.badssl.com/')
        WebMock.disable!
        expect { http.post('/') }.to raise_error(OpenSSL::SSL::SSLError)
        WebMock.enable!
      end
    end
  end
end
