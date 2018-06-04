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
        expect(request.url).to eq(
          protocol: 'http',
          hostname: 'example.org',
          port: '80',
          pathname: '/somewhere/in/there',
          search: 'q=yes',
          hash: nil,
          full: 'http://example.org/somewhere/in/there?q=yes'
        )
        expect(request.headers).to eq(
          'Content-Type' => 'application/json'
        )
      end
    end
  end
end
