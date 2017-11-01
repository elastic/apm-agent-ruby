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

            expect(block_).to have_received(:call).with(Transaction)
            expect(result).to be_a Transaction
          end
        end
      end
    end
  end
end
