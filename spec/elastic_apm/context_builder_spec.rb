# frozen_string_literal: true

module ElasticAPM
  RSpec.describe ContextBuilder do
    describe '#build' do
      let(:config) { Config.new }
      let(:subject) { described_class.new(config) }

      it 'enriches request' do
        env = Rack::MockRequest.env_for(
          '/somewhere/in/there?q=yes',
          method: 'POST',
          'HTTP_COOKIE' => 'things=1'
        )
        env['HTTP_CONTENT_TYPE'] = 'application/json'

        context = subject.build(rack_env: env, for_type: :transaction)
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

        expect(request.cookies).to eq('things' => '1')
        # Make sure we have a clone and not the original
        expect(request.cookies).to_not be env['rack.request.cookie_hash']

        expect(request.headers).to eq(
          'Content-Type' => 'application/json',
          'Cookie' => 'things=1'
        )
      end

      context 'with form body' do
        let(:config) { Config.new capture_body: 'all' }

        it 'includes body' do
          env = Rack::MockRequest.env_for(
            '/',
            method: 'POST',
            params: { thing: 123 }
          )

          result = subject.build(rack_env: env, for_type: :transaction)

          expect(result.request.body).to eq('thing' => '123')
        end
      end

      context 'with binary body' do
        let(:config) { Config.new capture_body: 'all' }

        it 'includes form data' do
          Tempfile.open('test', encoding: 'binary') do |f|
            f.write('0123456789' * 1024 * 1024)
            f.rewind

            env = Rack::MockRequest.env_for(
              '/',
              method: 'POST',
              params: {
                file: Rack::Multipart::UploadedFile.new(f.path, 'binary')
              }
            )

            result = subject.build(rack_env: env, for_type: :transaction)

            expect(result.request.body).to match('file' => Hash)
            expect(result.request.body['file'][:type]).to eq 'binary'
          end
        end
      end

      context 'with JSON body' do
        let(:config) { Config.new capture_body: 'all' }

        it 'includes body in utf-8' do
          env = Rack::MockRequest.env_for(
            '/',
            'CONTENT_TYPE' => 'application/json',
            input: { something: 'everything' }.to_json
          )

          result = subject.build(rack_env: env, for_type: :transaction)

          expect(result.request.body).to eq '{"something":"everything"}'
          expect(result.request.body.encoding).to eq Encoding::UTF_8
        end
      end
    end
  end
end
