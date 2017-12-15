# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe ErrorBuilder do
    subject { ErrorBuilder.new Config.new }

    context 'with an exception' do
      it 'builds an error from an exception', :mock_time do
        error = subject.build_exception(actual_exception)

        expect(error.culprit).to eq '/'
        expect(error.timestamp).to eq 694_224_000_000_000
        expect(error.exception.message).to eq 'ZeroDivisionError: divided by 0'
        expect(error.exception.type).to eq 'ZeroDivisionError'
        expect(error.exception.handled).to be true
      end

      it 'attaches a context from Rack' do
        env = Rack::MockRequest.env_for(
          '/somewhere/in/there?q=yes',
          method: 'POST'
        )
        env['HTTP_CONTENT_TYPE'] = 'application/json'
        error = subject.build_exception actual_exception, rack_env: env

        request = error.context.request
        expect(request).to be_a(Error::Context::Request)
        expect(request.method).to eq 'POST'
        expect(request.url).to eq(
          protocol: 'http',
          hostname: 'example.org',
          port: 80,
          pathname: '/somewhere/in/there',
          search: 'q=yes',
          hash: nil,
          raw: '/somewhere/in/there?q=yes'
        )
        expect(request.headers).to eq(
          'Content-Type' => 'application/json'
        )
      end
    end

    xcontext 'with a log' do
      it 'builds an error from a message' do
        error = subject.build_log 'Things went 💥', caller: caller

        pp error

        # expect(error.culprit).to eq 'Things went 💥'
        expect(error.log.stacktrace).to be_a Array
        expect(error.log.stacktrace.length).to be_gt_than(0)
      end
    end
  end
end
