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
      should delegate :transaction,
        to: agent, args: ['T', nil, { context: nil }]
    end
    it do
      should delegate :report, to: agent, args: ['E', { handled: nil }]
    end
    it do
      should delegate :report_message,
        to: agent, args: ['NOT OK', { backtrace: Array }]
    end
    it { should delegate :set_tag, to: agent, args: [nil, nil] }
    it { should delegate :set_custom_context, to: agent, args: [nil] }
    it { should delegate :set_user, to: agent, args: [nil] }

    describe '#add_filter' do
      it { should delegate :add_filter, to: agent, args: [nil, -> {}] }

      it 'needs either callback or block' do
        expect { subject.add_filter(:key) }.to raise_error(ArgumentError)

        expect do
          subject.add_filter(:key) { 'ok' }
        end.to_not raise_error
      end
    end

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
