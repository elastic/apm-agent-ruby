# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Agent do
    context 'life cycle' do
      describe '.start' do
        it 'starts an instance and only one' do
          first_instance = Agent.start Config.new
          expect(Agent.instance).to_not be_nil
          expect(Agent.start(Config.new)).to be first_instance

          Agent.stop # clean up
        end
      end

      describe '.stop' do
        it 'kill the running instance' do
          Agent.start Config.new
          Agent.stop
          expect(Agent.instance).to be_nil
        end
      end
    end

    context 'instrumentation' do
      subject { Agent.new Config.new }

      describe '#transaction' do
        it 'returns a new transaction and sets it as current' do
          transaction = subject.transaction 'Test'
          expect(transaction).to_not be_nil
          expect(subject.current_transaction).to be transaction
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

      describe '#trace' do
        it 'delegates to current transaction' do
          expect(subject).to delegate :trace, to: subject.current_transaction
        end
      end
    end

    # reporting

    context 'reporting' do
      subject { Agent.new Config.new }

      describe '#submit_transaction' do
        context "when it shouldn't send" do
          it 'adds the transaction as pending' do
            transaction = Transaction.new(nil, 'Test-1').done

            subject.submit_transaction transaction

            expect(subject.pending_transactions.length).to be 1
            expect(subject.queue.length).to be 0
          end
        end

        context 'when it should send' do
          it 'adds the transaction and flushes pending to the queue' do
            transaction = Transaction.new(nil, 'Test-1').done

            allow(subject).to receive(:should_send_transactions?) { true }
            subject.submit_transaction transaction

            expect(subject.pending_transactions.length).to be 0
            expect(subject.queue.length).to be 1
          end
        end
      end
    end
  end
end
