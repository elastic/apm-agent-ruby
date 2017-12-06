# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Http, :with_fake_server do
    describe '#post' do
      subject { Http.new Config.new(app_name: 'app-1') }

      it 'makes a post request' do
        subject.post('/v1/transactions', id: 1)

        body = {
          id: 1,
          service: {
            name: 'app-1',
            agent: {
              name: 'ruby',
              version: VERSION
            }
          }
        }.to_json

        expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
          body: body,
          headers: {
            'Content-Type' => Http::CONTENT_TYPE,
            'User-Agent' => Http::USER_AGENT,
            'Content-Length' => body.bytesize.to_s
          }
        )
      end

      it 'includes bearer token if provided' do
        http = Http.new Config.new(secret_token: 'abc123')
        http.post('/v1/transactions')

        expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
          headers: {
            'Content-Type' => Http::CONTENT_TYPE,
            'User-Agent' => Http::USER_AGENT,
            'Content-Length' => '69',
            'Authorization' => 'Bearer abc123'
          }
        )
      end
    end
  end
end
