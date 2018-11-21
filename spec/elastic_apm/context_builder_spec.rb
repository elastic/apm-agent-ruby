# frozen_string_literal: true

module ElasticAPM
  RSpec.describe ContextBuilder do
    describe '#build' do
      let(:subject) { described_class.new(Config.new) }

      it 'enriches request' do
        env = Rack::MockRequest.env_for(
          '/somewhere/in/there?q=yes',
          method: 'POST'
        )
        env['HTTP_CONTENT_TYPE'] = 'application/json'

        context = subject.build(env)
        request = context.request

        expect(request).to be_a(Context::Request)
        expect(request.method).to eq 'POST'

        expect(request.url).to be_a Context::Request::Url
        expect(request.url.protocol).to eq 'http'
        expect(request.url.hostname).to eq 'example.org'
        expect(request.url.port).to eq '80'
        expect(request.url.pathname).to eq '/somewhere/in/there'
        expect(request.url.search).to eq 'q=yes'
        expect(request.url.hash).to eq nil
        expect(request.url.full).to eq 'http://example.org/somewhere/in/there?q=yes'

        expect(request.headers).to eq(
          'Content-Type' => 'application/json'
        )
      end
    end
  end
end
