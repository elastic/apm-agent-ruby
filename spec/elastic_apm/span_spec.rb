# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Span do
    subject do
      described_class.new(
        name: 'Spannest name',
        transaction: transaction,
        parent: transaction,
        trace_context: trace_context
      )
    end

    let(:trace_context) do
      TraceContext.new(
        traceparent: TraceContext::Traceparent.parse(
                       "00-#{'1' * 32}-#{'2' * 16}-01"
                     )
      )
    end

    let(:transaction) { Transaction.new config: Config.new }

    describe '#initialize' do
      its(:name) { should eq 'Spannest name' }
      its(:type) { should eq 'custom' }
      its(:subtype) { should be nil }
      its(:action) { should be nil }
      its(:transaction) { should eq transaction }
      its(:trace_context) { should eq trace_context }
      its(:timestamp) { should be_nil }
      its(:context) { should be_a Span::Context }
      its(:trace_id) { should eq trace_context.trace_id }
      its(:id) { should eq trace_context.id }
      its(:parent_id) { should eq trace_context.parent_id }
      its(:sample_rate) { is_expected.to eq transaction.sample_rate }

      context 'with a dot-separated type' do
        it 'splits type' do
          span =
            described_class.new(
              name: 'Spannest name',
              type: 'typest.subest.actionest',
              transaction: transaction,
              parent: transaction,
              trace_context: trace_context
            )

          expect(span.type).to eq 'typest'
          expect(span.subtype).to eq 'subest'
          expect(span.action).to eq 'actionest'
        end
      end
    end

    describe '#start', :mock_time do
      let(:transaction) { Transaction.new config: Config.new }

      subject do
        described_class.new(
          name: 'Spannest name',
          transaction: transaction,
          parent: transaction,
          trace_context: trace_context
        )
      end

      it 'has a relative and absolute start time', :mock_time do
        transaction.start
        travel 100
        expect(subject.start).to be subject
        expect(subject.timestamp - transaction.timestamp).to eq 100
      end
    end

    describe '#stopped', :mock_time do
      let(:transaction) { Transaction.new config: Config.new }

      subject do
        described_class.new(
          name: 'Spannest name',
          transaction: transaction,
          parent: transaction,
          trace_context: trace_context
        )
      end

      it 'sets duration' do
        transaction.start
        subject.start
        travel 100
        subject.stop

        expect(subject).to be_stopped
        expect(subject.duration).to be 100
      end

      it 'calculates self_time' do
        subject.start
        travel 100
        child = Span.new(
          name: 'span',
          transaction: transaction,
          trace_context: nil,
          parent: subject
        ).start
        travel 100
        child.stop
        travel 100
        subject.stop

        expect(child.self_time).to eq 100
        expect(subject.self_time).to eq 200
      end
    end

    describe '#done', :mock_time do
      let(:duration_us) { 5_100 }
      let(:config) { Config.new }

      subject do
        described_class.new(
          name: 'Span',
          transaction: transaction,
          parent: transaction,
          trace_context: trace_context,
          stacktrace_builder: StacktraceBuilder.new(config)
        )
      end

      before do
        subject.original_backtrace = caller
        subject.start
        travel duration_us
        subject.done
      end

      it { should be_stopped }
      its(:duration) { should be duration_us }
    end

    describe "#prepare_for_serialization", :mock_time do
      let(:duration_us) { 5_100 }
      let(:span_frames_min_duration) { '5ms' }

      let(:config) do
        Config.new(span_frames_min_duration: span_frames_min_duration)
      end

      subject do
        described_class.new(
          name: 'Span',
          transaction: transaction,
          parent: transaction,
          trace_context: trace_context,
          stacktrace_builder: StacktraceBuilder.new(config)
        )
      end

      before do
        subject.original_backtrace = caller
        subject.start
        travel duration_us
        subject.done

        subject.prepare_for_serialization!
      end

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
