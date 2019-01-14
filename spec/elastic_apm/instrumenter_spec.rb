# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Instrumenter, :intercept do
    let(:config) { Config.new }
    let(:stacktrace_builder) { StacktraceBuilder.new(config) }
    let(:callback) { ->(*_) {} }
    before { allow(callback).to receive(:call) }

    subject do
      Instrumenter.new(
        config,
        stacktrace_builder: stacktrace_builder,
        &callback
      )
    end

    context 'life cycle' do
      describe '#stop' do
        let(:subscriber) { double(register!: true, unregister!: true) }

        before do
          subject.subscriber = subscriber

          subject.start_transaction
          subject.stop
        end

        its(:current_transaction) { should be_nil }

        it 'deletes thread local' do
          expect(Thread.current[ElasticAPM::Instrumenter::TRANSACTION_KEY])
            .to be_nil
        end

        it 'unregisters subscriber' do
          expect(subscriber).to have_received(:unregister!)
        end
      end
    end

    describe '#subscriber=' do
      it 'registers the subscriber' do
        subscriber = double(register!: true)
        subject.subscriber = subscriber
        expect(subscriber).to have_received(:register!)
      end
    end

    describe '#start_transaction' do
      it 'returns a new transaction and sets it as current' do
        context = Context.new
        transaction = subject.start_transaction 'Test', 't', context: context
        expect(transaction.name).to eq 'Test'
        expect(transaction.type).to eq 't'
        expect(transaction.id).to be subject.current_transaction.id
        expect(transaction.context).to be context

        expect(subject.current_transaction).to be transaction
      end

      it 'explodes if called inside other transaction' do
        subject.start_transaction 'Test'

        expect { subject.start_transaction 'Test' }
          .to raise_error(ExistingTransactionError)
      end

      context 'when instrumentation is disabled' do
        let(:config) { Config.new(instrument: false) }

        it 'is nil' do
          expect(subject.start_transaction).to be nil
          expect(subject.current_transaction).to be nil
        end
      end
    end

    describe '#end_transaction' do
      it 'is nil when no transaction' do
        expect(subject.end_transaction).to be nil
      end

      it 'ends and enqueues current transaction' do
        transaction = subject.start_transaction

        return_value = subject.end_transaction('result')

        expect(return_value).to be transaction
        expect(transaction).to be_stopped
        expect(transaction.result).to be 'result'
        expect(subject.current_transaction).to be nil
        expect(callback).to have_received(:call).with(transaction)
      end
    end

    describe '#start_span' do
      context 'when no transaction' do
        it { expect(subject.start_span('Span')).to be nil }
      end

      context 'when transaction unsampled' do
        let(:config) { Config.new(transaction_sample_rate: 0.0) }

        it 'skips spans' do
          transaction = subject.start_transaction
          expect(transaction).to_not be_sampled

          span = subject.start_span 'Span'
          expect(span).to be_nil
        end
      end

      context 'inside a sampled transaction' do
        let(:transaction) { subject.start_transaction }
        before { transaction }

        it "increments transaction's span count" do
          expect { subject.start_span 'Span' }
            .to change(transaction, :started_spans).by 1
        end

        it 'starts and returns a span' do
          span = subject.start_span 'Span'

          expect(span).to be_a Span
          expect(span).to be_started
          expect(span.transaction_id).to eq transaction.id
          expect(span.parent_id).to eq transaction.id
          expect(subject.current_span).to eq span
        end

        context 'with a backtrace' do
          it 'saves original backtrace for later' do
            backtrace = caller
            span = subject.start_span 'Span', backtrace: backtrace
            expect(span.original_backtrace).to eq backtrace
          end
        end

        context 'inside another span' do
          it 'sets current span as parent' do
            parent = subject.start_span 'Level 1'
            child = subject.start_span 'Level 2'

            expect(child.parent_id).to be parent.id
          end
        end

        context 'when max spans reached' do
          let(:config) { Config.new(transaction_max_spans: 1) }
          before do
            2.times do |i|
              subject.start_span i.to_s
              subject.end_span
            end
          end

          it "increments transaction's span count, returns nil" do
            expect do
              expect(subject.start_span('Span')).to be nil
            end.to change(transaction, :started_spans).by 1
          end
        end
      end
    end

    describe '#end_span' do
      context 'when missing span' do
        before { subject.start_transaction }
        it { expect(subject.end_span).to be nil }
      end

      context 'inside transaction and span' do
        let(:transaction) { subject.start_transaction }
        let(:span) { subject.start_span 'Span' }

        before do
          transaction
          span
        end

        it 'closes span, sets new current, enqueues' do
          return_value = subject.end_span

          expect(return_value).to be span
          expect(span).to be_stopped
          expect(subject.current_span).to be nil
          expect(callback).to have_received(:call).with(span)
        end

        context 'inside another span' do
          it 'sets current span to parent' do
            nested = subject.start_span 'Nested'

            return_value = subject.end_span

            expect(return_value).to be nested
            expect(subject.current_span).to be span
          end
        end
      end
    end

    describe '#set_tag' do
      it 'sets tag on currenct transaction' do
        transaction = subject.start_transaction 'Test'
        subject.set_tag :things, 'are all good!'

        expect(transaction.context.tags).to match(things: 'are all good!')
      end

      it 'de-dots keys' do
        transaction = subject.start_transaction 'Test'
        subject.set_tag 'th.ings', 'are all good!'
        subject.set_tag 'thi"ngs', 'are all good!'
        subject.set_tag 'thin*gs', 'are all good!'

        expect(transaction.context.tags).to match(
          th_ings: 'are all good!',
          thi_ngs: 'are all good!',
          thin_gs: 'are all good!'
        )
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

        user = transaction.context.user
        expect(user.id).to eq '1'
        expect(user.email).to eq 'a@a'
        expect(user.username).to eq 'abe'
      end
    end
  end
end
