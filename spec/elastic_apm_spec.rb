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
    it do
      should delegate :transaction, to: agent, args: [
        'T',
        nil,
        { rack_env: nil }
      ]
    end
    it { should delegate :span, to: agent, args: ['t', nil, { context: nil }] }
    it do
      should delegate :report, to: agent, args: [
        'E',
        { rack_env: nil, handled: nil }
      ]
    end
    it do
      should delegate :report_message, to: agent, args: [
        'NOT OK', { backtrace: Array }
      ]
    end
    it { should delegate :set_tag, to: agent, args: [nil, nil] }

    after { ElasticAPM.stop }
  end

  context 'when not running' do
    it 'still yields block' do
      ran = false

      ElasticAPM.transaction('Test') { ran = true }

      expect(ran).to be true
    end
  end
end
