# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Http, :with_fake_server do
    describe '#post' do
      subject { Http.new Config.new(app_name: 'app-1', environment: 'test') }

      it 'makes a post request' do
        subject.post('/v1/transactions', things: [{ test: true }])

        body = {
          service: ServiceInfo.build(subject.config),
          things: [{ test: true }]
        }.to_json

        expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
          body: body,
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => "elastic-apm/ruby #{VERSION}",
            'Content-Length' => body.bytesize.to_s
          }
        )
      end

      it 'includes bearer token if provided' do
        http = Http.new Config.new(secret_token: 'abc123')
        http.post('/v1/transactions')

        expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
          headers: { 'Authorization' => 'Bearer abc123' }
        )
      end
    end
  end
end
