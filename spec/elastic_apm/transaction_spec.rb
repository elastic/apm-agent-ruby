# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Transaction do
    describe '#initialize', :mock_time do
      it 'has a root trace, timestamp and start time' do
        transaction = Transaction.new nil, 'Test'

        expect(transaction.traces.length).to be 1
        expect(transaction.timestamp).to eq 694_224_000
        expect(transaction.start_time).to eq 694_224_000_000_000_000
      end
    end

    describe '#release', :mock_time do
      it 'sets clients current transaction to nil' do
        agent = Struct.new(:current_transaction).new(1)
        transaction = Transaction.new agent, 'Test'
        transaction.release

        expect(agent.current_transaction).to be_nil
      end
    end

    describe '#done', :mock_time do
      it 'it sets result, durations and ends root trace' do
        transaction = Transaction.new nil, 'Test'

        travel 100
        transaction.done(200)

        expect(transaction.result).to be 200
        expect(transaction.traces.first).to be_done
        expect(transaction.duration).to eq 100_000_000
      end
    end

    describe '#submit', :mock_time do
      it 'ends transaction and submits it to the agent' do
        mock_agent = double(
          Agent,
          submit_transaction: true,
          :current_transaction= => true
        )
        transaction = Transaction.new mock_agent, 'Test'

        travel 100
        transaction.submit 200

        expect(transaction.result).to be 200
        expect(transaction).to be_done
        expect(mock_agent).to have_received(:current_transaction=)
        expect(mock_agent)
          .to have_received(:submit_transaction)
          .with transaction
      end
    end

    describe '#running_traces', :mock_time do
      it 'returns running traces' do
        transaction = Transaction.new nil, 'Test'

        transaction.trace 'test' do
          travel 100
        end

        running_trace = transaction.trace 'test2'
        travel 100

        expect(transaction.running_traces)
          .to eq [transaction.root_trace, running_trace]
      end
    end

    describe '#trace', :mock_time do
      let(:transaction) { Transaction.new nil, 'Test' }
      subject do
        transaction

        travel 100

        trace = transaction.trace 'test' do |t|
          travel 100
          t
        end

        transaction.done

        trace
      end

      it { should be_done }
      it { should_not be_running }

      it 'sets start time' do
        expect(subject.start_time).to eq 694_224_000_100_000_000
      end

      it 'knows its parent traces' do
        expect(subject.parents).to eq [transaction.root_trace]
      end

      it 'adds trace to traces' do
        expect(transaction.traces).to eq [transaction.root_trace, subject]
      end
    end
  end
end
