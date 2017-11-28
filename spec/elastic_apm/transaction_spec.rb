# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Transaction do
    describe '#initialize', :mock_time do
      it 'has no spans, timestamp and start time' do
        transaction = Transaction.new nil, 'Test'

        expect(transaction.spans.length).to be 0
        expect(transaction.timestamp).to eq 694_224_000_000_000
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
      it 'it sets result, durations' do
        transaction = Transaction.new nil, 'Test'

        travel 100
        transaction.done(200)

        expect(transaction.result).to be 200
        expect(transaction.duration).to eq 100_000
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

    describe '#running_spans', :mock_time do
      it 'returns running spans' do
        transaction = Transaction.new nil, 'Test'

        transaction.span 'test' do
          travel 100
        end

        running_span = transaction.span 'test2'
        travel 100

        expect(transaction.running_spans).to eq [running_span]
      end
    end

    describe '#span', :mock_time do
      let(:transaction) { Transaction.new nil, 'Test' }
      subject do
        transaction

        travel 100

        span = transaction.span 'test' do |t|
          travel 100
          t
        end

        transaction.done

        span
      end

      it { should be_done }
      it { should_not be_running }

      it 'gets an id' do
        expect(subject.id).to be 0
      end

      it 'sets start time' do
        expect(subject.relative_start).to eq 100_000
      end

      it 'knows its parent spans' do
        expect(subject.parent).to be_nil
      end

      it 'adds span to spans' do
        expect(transaction.spans).to eq [subject]
      end
    end
  end
end
