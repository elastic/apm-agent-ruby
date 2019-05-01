# frozen_string_literal: true

module ElasticAPM
  RSpec.describe ErrorBuilder do
    let(:config) { Config.new }

    subject { ErrorBuilder.new Agent.new(config) }

    context 'with an exception' do
      it 'builds an error from an exception', :mock_time, unless: jruby_92? do
        error = subject.build_exception(actual_exception)

        expect(error.culprit).to eq '/'
        expect(error.timestamp).to eq 694_224_000_000_000
        expect(error.exception.message).to eq 'ZeroDivisionError: divided by 0'
        expect(error.exception.type).to eq 'ZeroDivisionError'
        expect(error.exception.handled).to be true
      end

      it 'sets properties from current transaction', :intercept do
        env = Rack::MockRequest.env_for(
          '/somewhere/in/there?q=yes',
          method: 'POST'
        )
        env['HTTP_CONTENT_TYPE'] = 'application/json'

        begin
          ElasticAPM.start(default_tags: { more: 'totes' })

          context =
            ElasticAPM.build_context rack_env: env, for_type: :transaction

          transaction = ElasticAPM.with_transaction context: context do |txn|
            ElasticAPM.set_tag(:my_tag, '123')
            ElasticAPM.set_custom_context(all_the_other_things: 'blah blah')
            ElasticAPM.set_user(Struct.new(:id).new(321))
            ElasticAPM.report actual_exception

            txn
          end
        ensure
          ElasticAPM.stop
        end

        error = @intercepted.errors.last
        expect(error.transaction).to eq(sampled: true)
        expect(error.transaction_id).to eq transaction.id
        expect(error.trace_id).to eq transaction.trace_id
        expect(error.context.tags).to match(my_tag: '123', more: 'totes')
        expect(error.context.custom)
          .to match(all_the_other_things: 'blah blah')
        # expect(error.trace_id).to eq transaction.trace_id
      end
    end

    context 'with a log' do
      it 'builds an error from a message', :mock_time, unless: jruby_92? do
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
