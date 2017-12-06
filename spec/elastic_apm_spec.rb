# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticAPM do
  describe 'life cycle' do
    it 'starts and stops the agent' do
      ElasticAPM.start ElasticAPM::Config.new
      expect(ElasticAPM::Agent).to be_running

      ElasticAPM.stop
      expect(ElasticAPM::Agent).to_not be_running
    end
  end

  context 'when running' do
    before { ElasticAPM.start }

    let(:agent) { ElasticAPM.agent }

    it { should delegate :current_transaction, to: agent }
    it { should delegate :transaction, to: agent, args: ['T', nil, nil] }
    it { should delegate :span, to: agent, args: ['t', nil, nil] }
    it do
      should delegate :report, to: agent, args: [
        'E',
        { rack_env: nil, handled: nil }
      ]
    end

    after { ElasticAPM.stop }
  end
end
