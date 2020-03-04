# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Transaction do
    subject { described_class.new config: config }
    let(:config) { Config.new }

    describe '#initialize', :mock_time do
      its(:id) { should_not be_nil }
      its(:type) { should eq 'custom' }
      it { should be_sampled }
      its(:trace_context) { should be_a TraceContext }
      its(:context) { should be_a Context }
      its(:config) { should be_a Config }
      its(:started_spans) { should be 0 }
      its(:dropped_spans) { should be 0 }
      its(:notifications) { should be_empty }
      its(:trace_id) { should be subject.trace_context.trace_id }

      context 'with labels from context and config' do
        let(:config) { Config.new(default_labels: { args: 'yes' }) }
        it 'merges labels' do
          context = Context.new(labels: { context: 'yes' })
          subject = described_class.new(config: config, context: context)
          expect(subject.context.labels).to match(args: 'yes', context: 'yes')
        end
      end
    end

    describe '#start', :mock_time do
      it 'sets timestamp' do
        expect(subject.start.timestamp).to be Util.micros
      end
    end

    describe '#stop', :mock_time do
      it 'sets duration' do
        subject.start
        travel 100
        expect(subject.stop.duration).to eq 100
        expect(subject).to be_stopped
      end

      it 'calculates self_time' do
        subject.start
        travel 100
        subject.stop
        expect(subject.self_time).to eq 100
      end

      context 'with a child span' do
        it 'calculates self_time' do
          transaction = subject.start
          travel 100
          span = Span.new(
            name: 'span',
            transaction: transaction,
            trace_context: nil,
            parent: transaction
          ).start
          travel 100
          span.stop
          travel 100
          subject.stop
          expect(subject.duration).to eq 300
          expect(subject.self_time).to eq 200
        end
      end
    end

    describe '#done', :mock_time do
      it 'it sets result, durations' do
        subject.start
        travel 100
        subject.done('HTTP 200')

        expect(subject).to be_stopped
        expect(subject.duration).to be 100
        expect(subject.result).to eq 'HTTP 200'
      end
    end

    describe '#ensure_parent_id' do
      it 'sets and returns a new parent id if missing' do
        parent_id = subject.ensure_parent_id

        expect(subject.parent_id).to_not be_nil
        expect(subject.parent_id).to eq parent_id
      end

      it 'keeps and returns current parent id if set' do
        trace_context = TraceContext.new
        trace_context.traceparent.parent_id = 'things'
        subject = Transaction.new config: config, trace_context: trace_context

        parent_id = subject.ensure_parent_id

        expect(parent_id).to eq 'things'
        expect(subject.parent_id).to eq 'things'
      end
    end

    describe '#inc_started_spans!' do
      let!(:result) { subject.inc_started_spans! }
      it 'increments started count' do
        expect(subject.started_spans).to be(1)
      end

      it 'returns true' do
        expect(result).to be true
      end

      context 'when max spans is reached' do
        let(:config) { Config.new(transaction_max_spans: 3) }
        let!(:result) do
          3.times { subject.inc_started_spans! }
          subject.inc_started_spans!
        end
        it 'increments dropped spans' do
          expect(subject.dropped_spans).to be(1)
        end

        it 'returns false' do
          expect(result).to be false
        end
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
