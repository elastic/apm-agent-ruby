# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Span do
    subject { described_class.new 'Spannest name' }

    describe '#initialize' do
      its(:name) { should be 'Spannest name' }
      its(:type) { should be 'custom' }
      its(:transaction_id) { should be_nil }
      its(:timestamp) { should be_nil }
      its(:trace_id) { should be_nil }
      its(:parent_id) { should be_nil }
      its(:context) { should be_nil }

      context 'with a transaction' do
        let(:transaction) { Transaction.new }

        subject do
          described_class.new 'Spannest name', transaction: transaction
        end

        its(:transaction_id) { should be transaction.id }
        its(:timestamp) { should be transaction.timestamp }
        its(:trace_id) { should be transaction.trace_id }
      end

      context 'with a parent' do
        let(:span) { Span.new 'Span' }
        subject { described_class.new 'Span', parent: span }
        its(:parent_id) { should be span.id }
      end
    end

    describe '#start', :mock_time do
      let(:transaction) { Transaction.new }

      subject { described_class.new('Span', transaction: transaction) }

      it 'has a relative and absolute start time', :mock_time do
        transaction.start
        travel 100
        expect(subject.start).to be subject
        expect(subject.timestamp - transaction.timestamp).to eq 100_000
      end
    end

    describe '#stopped', :mock_time do
      let(:transaction) { Transaction.new }

      subject { described_class.new('Span', transaction: transaction) }

      it 'sets duration' do
        transaction.start
        subject.start
        travel 100
        subject.stop

        expect(subject).to be_stopped
        expect(subject.duration).to be 100_000
      end
    end

    describe '#done', :mock_time do
      let(:transaction) { Transaction.new }
      let(:duration) { 100 }
      let(:span_frames_min_duration) { '5ms' }
      let(:config) do
        Config.new(span_frames_min_duration: span_frames_min_duration)
      end

      subject do
        described_class.new(
          'Span',
          transaction: transaction,
          stacktrace_builder: StacktraceBuilder.new(config)
        )
      end

      before do
        transaction.start
        subject.original_backtrace = caller
        subject.start
        travel duration
        subject.done
      end

      it { should be_stopped }
      its(:duration) { should be 100_000 }
      its(:stacktrace) { should be_a Stacktrace }

      context 'when shorter than min for stacktrace' do
        let(:span_frames_min_duration) { '1s' }
        its(:stacktrace) { should be_nil }
      end

      context 'when short, but min duration is off' do
        let(:duration) { 0 }
        let(:span_frames_min_duration) { '-1' }
        its(:stacktrace) { should be_a Stacktrace }
      end
    end
  end
end
