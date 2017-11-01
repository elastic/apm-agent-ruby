# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticAPM do
  describe 'life cycle' do
    it 'starts and stops the agent' do
      # expect(ElasticAPM::Agent).to receive(:start) { true }
      ElasticAPM.start nil
      expect(ElasticAPM::Agent).to be_started

      ElasticAPM.stop
      expect(ElasticAPM::Agent).to_not be_started
    end
  end

  it { should_not be_started }

  context 'when apm is started', :with_agent do
    it { should be_started }

    it do
      should delegate(
        :transaction, to: ElasticAPM.agent, args: ['Test', nil, nil]
      )
    end

    xit 'block example', :with_agent, :mock_time do
      transaction = ElasticAPM.transaction 'Test' do
        travel 100
        ElasticAPM.trace 'test1' do
          travel 100
          ElasticAPM.trace 'test1-1' do
            travel 100
          end
          ElasticAPM.trace 'test1-2' do
            travel 100
          end
          travel 100
        end
      end.done(true)

      expect(transaction).to be_done
      expect(transaction.duration).to eq 500_000_000
    end
  end
end
