# frozen_string_literal: true

require 'spec_helper'

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

      it 'enriches user' do
        class Controller
          ProbablyUser = Struct.new(:id, :email, :username)

          def current_user
            ProbablyUser.new(1, 'john@example.com', 'leroy')
          end
        end

        env = Rack::MockRequest.env_for '/',
          'action_controller.instance' => Controller.new
        context = subject.build(env)

        expect(context.user.id).to be 1
        expect(context.user.email).to eq 'john@example.com'
        expect(context.user.username).to eq 'leroy'
      end
    end
  end
end
