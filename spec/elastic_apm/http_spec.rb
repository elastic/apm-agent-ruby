# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Http, :with_fake_server do
    describe '#post' do
      subject { Http.new Config.new(app_name: 'app-1', environment: 'test') }

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
    end
  end
end
