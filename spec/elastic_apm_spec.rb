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

    describe '.start_transaction' do
      it 'starts a transaction' do
        transaction = ElasticAPM.start_transaction 'Test'
        expect(transaction).to be_a ElasticAPM::Transaction
        expect(transaction.name).to be 'Test'
      end
    end

    describe '.end_transaction', :mock_intake do
      it 'ends current transaction' do
        transaction = ElasticAPM.start_transaction 'Test'
        expect(ElasticAPM.current_transaction).to_not be_nil

        ElasticAPM.end_transaction
        expect(ElasticAPM.current_transaction).to be_nil
        expect(transaction).to be_done

        ElasticAPM.flush

        transaction = @mock_intake.transactions.first
        expect(transaction['name']).to eq 'Test'
      end
    end

    describe '.with_transaction' do
      let(:placeholder) { Struct.new(:transaction).new }

      subject do
        ElasticAPM.with_transaction('Block test') do |transaction|
          placeholder.transaction = transaction

          'original result'
        end
      end

      it 'wraps block in transaction' do
        subject

        expect(placeholder.transaction).to be_a ElasticAPM::Transaction
        expect(placeholder.transaction.name).to be 'Block test'
      end

      it { should be 'original result' }
    end

    describe '.start_span' do
      it 'starts a span' do
        ElasticAPM.start_transaction

        span = ElasticAPM.start_span 'Test'
        expect(span).to be_a ElasticAPM::Span
        expect(span.name).to be 'Test'
      end
    end

    describe '.end_span' do
      it 'ends current span' do
        ElasticAPM.start_transaction

        span = ElasticAPM.start_span 'Test'
        expect(ElasticAPM.current_span).to_not be_nil

        ElasticAPM.end_span
        expect(ElasticAPM.current_span).to be_nil
        expect(span).to be_done
      end
    end

    describe '.with_span' do
      let(:placeholder) { Struct.new(:spans).new([]) }

      before { ElasticAPM.start_transaction }

      subject do
        ElasticAPM.with_span('Block test') do |span1|
          placeholder.spans << span1

          ElasticAPM.with_span('All the way down') do |span2|
            placeholder.spans << span2

            'original result'
          end
        end
      end

      it 'wraps block in span' do
        subject

        expect(placeholder.spans.length).to be 2
        span1, span2 = placeholder.spans

        expect(span1.name).to be 'Block test'
        expect(span2.name).to be 'All the way down'
      end

      it { should be 'original result' }
    end

    it { should delegate :current_transaction, to: agent }

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

      ElasticAPM.with_transaction { ran = true }

      expect(ran).to be true
    end
  end

  describe 'DEPRECATED' do
    before { ElasticAPM.start }
    after { ElasticAPM.stop }

    before do
      allow(ElasticAPM).to receive(:warn) { true }
    end

    describe '.transaction' do
      it 'redirects to new apis' do
        expect(ElasticAPM).to receive(:start_transaction) { true }
        ElasticAPM.transaction

        expect(ElasticAPM).to receive(:with_transaction) { true }
        ElasticAPM.transaction { 'ok' }
      end
    end

    describe '.span' do
      it 'redirects to new apis' do
        expect(ElasticAPM).to receive(:start_span) { true }
        ElasticAPM.span('Name')

        expect(ElasticAPM).to receive(:with_span) { true }
        ElasticAPM.span('Name') { 'ok' }
      end
    end
  end
end
