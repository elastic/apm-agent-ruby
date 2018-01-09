# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Instrumenter do
    context 'life cycle' do
      it 'registers and unregisters' do
        mock_subscriber = double(Subscriber, register!: true, unregister!: true)
        mock_class = double(new: mock_subscriber)

        instrumenter =
          Instrumenter.new(nil, nil, subscriber_class: mock_class)

        instrumenter.start
        expect(mock_subscriber).to have_received(:register!)

        instrumenter.stop
        expect(mock_subscriber).to have_received(:unregister!)
      end

      it 'cleans up after itself' do
        instrumenter = Instrumenter.new(nil, nil)

        instrumenter.transaction 'T'

        expect(instrumenter.current_transaction).to_not be_nil

        instrumenter.stop

        expect(instrumenter.current_transaction).to be_nil
        expect(Thread.current[ElasticAPM::Instrumenter::KEY]).to be_nil
      end
    end

    describe '#transaction' do
      subject { Instrumenter.new(Config.new, nil) }

      it 'returns a new transaction and sets it as current' do
        context = Context.new
        transaction = subject.transaction 'Test', 't', context: context
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
    end

    describe '#span' do
      subject { Instrumenter.new(Config.new, nil) }

      it 'delegates to current transaction' do
        subject.current_transaction = double(span: true)
        expect(subject).to delegate :span, to: subject.current_transaction
      end
    end

    describe '#set_tag' do
      subject { Instrumenter.new(Config.new, nil) }

      it 'sets tag on currenct transaction' do
        transaction = subject.transaction 'Test' do |t|
          subject.set_tag :things, 'are all good!'
          t
        end

        expect(transaction.context.tags).to match(things: 'are all good!')
      end
    end

    describe '#set_custom_context' do
      subject { Instrumenter.new(Config.new, nil) }

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

    describe '#submit_transaction' do
      context "when it shouldn't send" do
        subject { Instrumenter.new(Config.new, nil) }

        it 'adds the transaction as pending' do
          transaction = subject.transaction('Test').done
          subject.submit_transaction transaction
          expect(subject.pending_transactions.length).to be 1
        end
      end

      context 'when it should send' do
        let(:mock_agent) { double(Agent, enqueue_transactions: true) }
        subject { Instrumenter.new(Config.new, mock_agent) }

        it 'adds the transaction and flushes pending to the queue' do
          transaction = subject.transaction('Test').done

          allow(subject).to receive(:should_flush_transactions?) { true }
          subject.submit_transaction transaction

          expect(subject.pending_transactions.length).to be 0
          expect(mock_agent)
            .to have_received(:enqueue_transactions).with [transaction]
        end
      end
    end
  end
end
