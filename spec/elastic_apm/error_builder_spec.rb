# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe ErrorBuilder do
    subject { ErrorBuilder.new Agent.new(Config.new) }

    context 'with an exception' do
      it 'builds an error from an exception', :mock_time do
        error = subject.build_exception(actual_exception)

        expect(error.culprit).to eq '/'
        expect(error.timestamp).to eq 694_224_000_000_000
        expect(error.exception.message).to eq 'ZeroDivisionError: divided by 0'
        expect(error.exception.type).to eq 'ZeroDivisionError'
        expect(error.exception.handled).to be true
      end

      it 'inherits context from current transaction', :with_fake_server do
        env = Rack::MockRequest.env_for(
          '/somewhere/in/there?q=yes',
          method: 'POST'
        )
        env['HTTP_CONTENT_TYPE'] = 'application/json'

        ElasticAPM.start
        context = ElasticAPM.build_context(env)

        ElasticAPM.transaction 'T', 't', context: context do
          ElasticAPM.report actual_exception
        end.submit 'ok'

        ElasticAPM.stop

        wait_for_requests_to_finish 2

        error_payload = FakeServer.requests.find do |payload|
          payload.key?('errors')
        end

        request = error_payload.dig('errors', 0, 'context', 'request')
        expect(request['method']).to eq 'POST'
      end
    end

    context 'with a log' do
      it 'builds an error from a message', :mock_time do
        error = subject.build_log 'Things went BOOM', backtrace: caller

        expect(error.culprit).to eq 'instance_exec'
        expect(error.log.message).to eq 'Things went BOOM'
        expect(error.timestamp).to eq 694_224_000_000_000
        expect(error.log.stacktrace).to be_a Stacktrace
        expect(error.log.stacktrace.length).to be > 0
      end
    end
  end
end
