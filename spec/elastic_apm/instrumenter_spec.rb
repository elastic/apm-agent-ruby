# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Instrumenter do
    let(:agent) { Agent.new(Config.new) }

    context 'life cycle' do
      it 'cleans up after itself' do
        instrumenter = Instrumenter.new(agent)

        instrumenter.transaction

        expect(instrumenter.current_transaction).to_not be_nil

        instrumenter.stop

        expect(instrumenter.current_transaction).to be_nil
        expect(Thread.current[ElasticAPM::Instrumenter::KEY]).to be_nil
      end
    end

    describe '#transaction' do
      subject { Instrumenter.new(agent) }

      it 'returns a new transaction and sets it as current' do
        context = Context.new
        transaction = subject.transaction 'Test', 't', context: context
        expect(transaction.name).to eq 'Test'
        expect(transaction.type).to eq 't'
        expect(transaction.id).to be subject.current_transaction.id
        expect(subject.current_transaction).to be transaction
        expect(transaction.context).to be context
      end

      it 'returns the current transaction if present' do
        transaction = subject.transaction 'Test'
        expect(subject.transaction('Test')).to eq transaction
      end

      context 'with a block' do
        it 'yields transaction and returns it' do
          block_ = ->(*args) {}
          allow(block_).to receive(:call)

          result = subject.transaction('Test') { |t| block_.call(t) }

          expect(block_).to have_received(:call).with(result)
        end
      end

      context 'when instrumentation is disabled' do
        let(:agent) { Agent.new Config.new(instrument: false) }
        it 'is a noop' do
          called = false

          transaction = subject.transaction do
            subject.span 'things' do
              called = true
            end
          end

          expect(transaction).to be_nil
          expect(called).to be true
        end
      end
    end

    describe '#span' do
      subject { Instrumenter.new(agent) }

      it 'delegates to current transaction' do
        subject.current_transaction = double(span: true)
        expect(subject).to delegate :span, to: subject.current_transaction
      end

      context 'with span_frames_min_duration' do
        let(:agent) { Agent.new(Config.new(span_frames_min_duration: 10)) }

        it 'collects stacktraces', :mock_time do
          t = subject.transaction do
            travel 100

            subject.span 'Things', backtrace: caller do
              travel 100
            end

            travel 100

            subject.span 'Short things', backtrace: caller do
              travel 5
            end
          end.done :ok

          expect(t.spans.length).to be 2
          expect(t.spans[0].stacktrace).to_not be_nil
          expect(t.spans[1].stacktrace).to be_nil
        end
      end
    end

    describe '#set_tag' do
      subject { Instrumenter.new(agent) }

      it 'sets tag on currenct transaction' do
        transaction = subject.transaction 'Test' do |t|
          subject.set_tag :things, 'are all good!'
          t
        end

        expect(transaction.context.tags).to match(things: 'are all good!')
      end
    end

    describe '#set_custom_context' do
      subject { Instrumenter.new(agent) }

      it 'sets custom context on transaction' do
        transaction = subject.transaction 'Test' do |t|
          subject.set_custom_context(one: 'is in', two: 2, three: false)
          t
        end

        expect(transaction.context.custom).to match(
          one: 'is in',
          two: 2,
          three: false
        )
      end
    end

    describe '#set_user' do
      User = Struct.new(:id, :email, :username)

      subject { Instrumenter.new(agent) }

      it 'sets user in context' do
        transaction = subject.transaction 'Test' do |t|
          subject.set_user(User.new(1, 'a@a', 'abe'))
          t
        end

        expect(transaction.context.user.to_h).to match(
          id: 1,
          email: 'a@a',
          username: 'abe'
        )
      end
    end

    describe '#submit_transaction' do
      it 'enqueues transaction on agent' do
        mock_agent = double(Agent, config: Config.new)
        transaction = double
        expect(mock_agent).to receive(:enqueue_transaction).with(transaction)
        subject = Instrumenter.new(mock_agent)
        subject.submit_transaction transaction
      end
    end

    context 'sampling' do
      subject do
        Instrumenter.new(Agent.new(Config.new(transaction_sample_rate: 0.0)))
      end

      it 'skips spans' do
        transaction = subject.transaction 'Test' do |t|
          t.span 'many things'
          t
        end.done

        expect(transaction).to_not be_sampled
        expect(transaction.spans).to be_empty
      end
    end
  end
end
