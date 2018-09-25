# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Instrumenter, :intercept do
    let(:config) { Config.new }
    let(:agent) { Agent.new(config) }
    subject { Instrumenter.new(agent) }

    after { agent.flush }

    context 'life cycle' do
      it 'cleans up after itself' do
        instrumenter = subject

        instrumenter.start_transaction

        expect(instrumenter.current_transaction).to_not be_nil

        instrumenter.stop

        expect(instrumenter.current_transaction).to be_nil
        thread_key = Thread.current[ElasticAPM::Instrumenter::TRANSACTION_KEY]
        expect(thread_key).to be_nil
      end
    end

    describe '#start_transaction' do
      it 'returns a new transaction and sets it as current' do
        context = Context.new
        transaction = subject.start_transaction 'Test', 't', context: context
        expect(transaction.name).to eq 'Test'
        expect(transaction.type).to eq 't'
        expect(transaction.id).to be subject.current_transaction.id
        expect(subject.current_transaction).to be transaction
        expect(transaction.context).to be context
      end

      it 'explodes if called inside other transaction' do
        subject.start_transaction 'Test'

        expect do
          subject.start_transaction 'Test'
        end.to raise_error(ExistingTransactionError)
      end

      context 'when instrumentation is disabled' do
        let(:config) { Config.new(instrument: false) }

        it 'is nil' do
          expect(subject.start_transaction).to be_nil
        end
      end
    end

    describe '#span' do
      context 'collecting stacktrace' do
        it 'knows when to' do
          subject.start_transaction

          span_with_backtrace =
            subject.start_span 'Things', backtrace: caller
          expect(span_with_backtrace.original_backtrace).to_not be_nil
          subject.end_span

          expect(subject.current_span).to be_nil

          span_without_backtrace =
            subject.start_span 'Short things'
          expect(span_without_backtrace.original_backtrace).to be_nil
          subject.end_span

          expect(subject.current_span).to be_nil

          subject.end_transaction
        end
      end
    end

    describe '#set_tag' do
      it 'sets tag on currenct transaction' do
        transaction = subject.start_transaction 'Test'
        subject.set_tag :things, 'are all good!'

        expect(transaction.context.tags).to match(things: 'are all good!')
      end
    end

    describe '#set_custom_context' do
      it 'sets custom context on transaction' do
        transaction = subject.start_transaction 'Test'
        subject.set_custom_context(one: 'is in', two: 2, three: false)

        expect(transaction.context.custom).to match(
          one: 'is in',
          two: 2,
          three: false
        )
      end
    end

    describe '#set_user' do
      User = Struct.new(:id, :email, :username)

      it 'sets user in context' do
        transaction = subject.start_transaction 'Test'
        subject.set_user(User.new(1, 'a@a', 'abe'))
        subject.end_transaction

        expect(transaction.context.user.to_h).to match(
          id: 1,
          email: 'a@a',
          username: 'abe'
        )
      end
    end

    describe '#end_transaction' do
      it 'ends and enqueues current transaction' do
        expect(agent).to receive(:enqueue)

        transaction = subject.start_transaction
        subject.end_transaction

        expect(transaction).to be_stopped
      end
    end

    describe 'DEPRECATED' do
      describe '#submit_transaction with a Transaction' do
        it 'enqueues transaction on agent' do
          mock_agent = double(Agent, config: Config.new)
          transaction = Transaction.new agent
          expect(mock_agent).to receive(:enqueue).with(transaction)
          subject = Instrumenter.new(mock_agent)
          subject.submit_transaction transaction
        end
      end
    end

    describe '#submit_span' do
      it 'enqueues span on agent' do
        expect(agent).to receive(:enqueue).with(Span)

        subject.start_transaction
        span = subject.start_span 'Span'
        subject.end_span

        expect(span).to be_stopped
      end
    end

    context 'sampling' do
      let(:config) { Config.new(transaction_sample_rate: 0.0) }

      it 'skips spans' do
        transaction = subject.start_transaction 'Test'
        span = subject.start_span 'many things'
        subject.end_transaction

        expect(transaction).to_not be_sampled
        expect(span).to be_nil
      end
    end
  end
end
