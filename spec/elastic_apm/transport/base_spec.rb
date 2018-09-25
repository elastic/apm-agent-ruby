# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    RSpec.describe Base, :mock_intake do
      let(:agent) { Agent.new Config.new }
      let(:instrumenter) { Instrumenter.new agent }

      subject { described_class.new agent.config }

      describe '#submit' do
        it 'takes records and sends them off' do
          transaction = instrumenter.start_transaction
          instrumenter.end_transaction

          error = agent.error_builder.build_exception actual_exception

          subject.submit transaction
          subject.submit error

          subject.flush

          expect(@mock_intake.requests.length).to be 1
          expect(@mock_intake.transactions.length).to be 1
          expect(@mock_intake.errors.length).to be 1

          agent.stop
        end

        it 'starts all requests with a metadata object' do
          subject.post({})
          subject.flush
          subject.post({})
          subject.flush
          expect(@mock_intake.requests.length).to be 2
          expect(@mock_intake.metadatas.length).to be 2
        end

        it 'filters sensitive data' do
          subject.post(
            transaction: {
              id: 1,
              context: { request: { headers: { ApiKey: 'OH NO!' } } }
            }
          )

          subject.flush

          expect(@mock_intake.transactions.length).to be 1

          transaction, = @mock_intake.transactions
          api_key = transaction['context']['request']['headers']['ApiKey']
          expect(api_key).to eq '[FILTERED]'
        end
      end
    end
  end
end
