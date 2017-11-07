# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Http, :allow_api_requests do
    describe '#post' do
      subject { Http.new Config.new }

      it 'makes a post request' do
        subject.post('/v1/transactions', { id: 1 })

        expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
          body: '{"id":1}',
          headers: {
            'Content-Type' => Http::CONTENT_TYPE,
            'User-Agent' => Http::USER_AGENT,
            'Content-Length' => 8
          }
        )
      end
    end
  end
end
