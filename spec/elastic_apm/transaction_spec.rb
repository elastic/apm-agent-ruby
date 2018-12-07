# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Transaction do
    describe '#initialize', :mock_time do
      its(:id) { should_not be_nil }
      its(:type) { should be 'custom' }
      it { should be_sampled }
      its(:trace_context) { should be_a TraceContext }
      its(:context) { should be_a Context }
      its(:started_spans) { should be 0 }
      its(:dropped_spans) { should be 0 }
      its(:notifications) { should be_empty }
      its(:trace_id) { should be subject.trace_context.trace_id }

      context 'with tags from context and args' do
        it 'merges tags' do
          context = Context.new(tags: { context: 'yes' })
          subject = described_class.new(tags: { args: 'yes' }, context: context)
          expect(subject.context.tags).to match(args: 'yes', context: 'yes')
        end
      end
    end

    describe '#start', :mock_time do
      it 'sets timestamp' do
        expect(subject.start.timestamp).to be Util.micros(@mocked_date)
      end
    end

    describe '#stop', :mock_time do
      it 'sets duration' do
        subject.start
        travel 100
        expect(subject.stop.duration).to eq 100_000
        expect(subject).to be_stopped
      end
    end

    describe '#done', :mock_time do
      it 'it sets result, durations' do
        subject.start
        travel 100
        subject.done('HTTP 200')

        expect(subject).to be_stopped
        expect(subject.duration).to be 100_000
        expect(subject.result).to be 'HTTP 200'
      end
    end

    describe '#ensure_parent_id' do
      it 'sets and returns a new parent id if missing' do
        parent_id = subject.ensure_parent_id

        expect(subject.parent_id).to_not be_nil
        expect(subject.parent_id).to be parent_id
      end

      it 'keeps and returns current if set' do
        trace_context = TraceContext.new
        trace_context.span_id = 'things'
        subject = Transaction.new trace_context: trace_context

        parent_id = subject.ensure_parent_id

        expect(parent_id).to be 'things'
        expect(subject.parent_id).to be 'things'
      end
    end

    describe '#inc_started_spans!' do
      it 'increments count' do
        expect { subject.inc_started_spans! }
          .to change(subject, :started_spans).by 1
      end
    end

    describe '#inc_dropped_spans!' do
      it 'increments count' do
        expect { subject.inc_dropped_spans! }
          .to change(subject, :dropped_spans).by 1
      end
    end

    describe '#max_spans_reached?' do
      let(:config) { Config.new(transaction_max_spans: 3) }

      subject { described_class.new }

      let(:result) { subject.max_spans_reached? config }

      context 'when below max' do
        it { expect(result).to be false }
      end

      context 'when maximum reached' do
        before { 4.times { subject.inc_started_spans! } }
        it { expect(result).to be true }
      end
    end

    describe '#add_response' do
      it 'adds http response to context' do
        subject.add_response(200, headers: { 'Ok' => 'yes' })
        expect(subject.context.response.status_code).to be 200
        expect(subject.context.response.headers).to match('Ok' => 'yes')
      end
    end
  end
end
