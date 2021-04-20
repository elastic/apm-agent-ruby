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

RSpec.describe ElasticAPM do
  describe 'life cycle' do
    it 'starts and stops the agent', :mock_intake do
      MockIntake.instance.stub!

      ElasticAPM.start
      expect(ElasticAPM::Agent).to be_running

      ElasticAPM.stop
      expect(ElasticAPM::Agent).to_not be_running
    end
  end

  describe '.restart', :mock_intake do
    before { MockIntake.instance.stub! }
    after { ElasticAPM.stop }
    context 'when the agent is not running' do
      it 'starts the agent' do
        ElasticAPM.restart
        expect(ElasticAPM::Agent).to be_running
      end
    end
    context 'when the agent is already running' do
      before { ElasticAPM.start }
      it 'restarts the agent' do
        expect(ElasticAPM::Agent).to receive(:stop)
          .at_least(:once).and_call_original
        expect(ElasticAPM::Agent).to receive(:start)
          .once.and_call_original
        ElasticAPM.restart
        expect(ElasticAPM::Agent).to be_running
      end
    end
    context 'when a new config is passed' do
      before { ElasticAPM.start }
      it 'restarts the agent with the new config' do
        ElasticAPM.restart(api_buffer_size: 10)
        expect(ElasticAPM::Agent).to be_running
        expect(ElasticAPM.agent.config.api_buffer_size).to be(10)
      end
    end
    context 'when no new config is passed' do
      before { ElasticAPM.start(api_buffer_size: 10) }
      it 'restarts the agent with the same config' do
        ElasticAPM.restart
        expect(ElasticAPM::Agent).to be_running
        expect(ElasticAPM.agent.config.api_buffer_size).to be(10)
      end
    end
  end

  context 'when running', :mock_intake do
    before do
      MockIntake.instance.stub!
      ElasticAPM.start config
    end

    let(:agent) { ElasticAPM.agent }
    let(:config) { ElasticAPM::Config.new }

    describe '.log_ids' do
      context 'with no current_transaction' do
        it 'returns empty string' do
          expect(ElasticAPM.log_ids).to eq('')
        end
      end

      context 'with a current transaction' do
        it 'includes transaction and trace ids' do
          transaction = ElasticAPM.start_transaction 'Test'
          expect(ElasticAPM.log_ids).to eq(
            "transaction.id=#{transaction.id} trace.id=#{transaction.trace_id}"
          )
        end
      end

      context 'with a current_span' do
        it 'includes transaction, span and trace ids' do
          trans = ElasticAPM.start_transaction
          span = ElasticAPM.start_span 'Test'
          expect(ElasticAPM.log_ids).to eq(
            "transaction.id=#{trans.id} span.id=#{span.id} " \
              "trace.id=#{trans.trace_id}"
          )
        end
      end

      context 'when passed a block' do
        it 'yields each id' do
          transaction = ElasticAPM.start_transaction
          span = ElasticAPM.start_span 'Test'
          ElasticAPM.log_ids do |transaction_id, span_id, trace_id|
            expect(transaction_id).to eq(transaction.id)
            expect(span_id).to eq(span.id)
            expect(trace_id).to eq(transaction.trace_id)
          end
        end
      end
    end

    describe '.start_transaction' do
      it 'delegates to agent' do
        expect(ElasticAPM.agent).to receive(:start_transaction)
        ElasticAPM.start_transaction
      end
      context 'when recording is false' do
        let(:config) { ElasticAPM::Config.new(recording: false) }
        it 'does not start a transaction' do
          ElasticAPM.start_transaction
          expect(ElasticAPM.current_transaction).to be nil
        end
      end
    end

    describe '.report' do
      context 'when recording is false' do
        let(:config) { ElasticAPM::Config.new(recording: false) }
        it 'does not report the exception' do
          ElasticAPM.report(Exception.new)
          expect(ElasticAPM.agent).not_to receive(:report)
        end
      end
    end

    describe '.report_message' do
      context 'when recording is false' do
        let(:config) { ElasticAPM::Config.new(recording: false) }
        it 'does not report the message' do
          ElasticAPM.report_message('this should not be reported')
          expect(ElasticAPM.agent).not_to receive(:report_message)
        end
      end
    end

    describe '.end_transaction' do
      it 'delegates to agent' do
        expect(ElasticAPM.agent).to receive(:end_transaction)
        ElasticAPM.end_transaction
      end
    end

    describe '.with_transaction' do
      subject do
        ElasticAPM.with_transaction do
          'original result'
        end
      end

      it 'delegates to agent' do
        expect(ElasticAPM.agent).to receive(:start_transaction)
        expect(ElasticAPM.agent).to receive(:end_transaction)
        subject
      end

      it { should eq 'original result' }
    end

    describe '.start_span' do
      it 'starts a span' do
        expect(ElasticAPM.agent).to receive(:start_span)
        ElasticAPM.start_span 'Test'
      end
      context 'when recording is false after the transaction is started' do
        it 'it creates a span' do
          ElasticAPM.start_transaction
          ElasticAPM.agent.config.recording = false
          ElasticAPM.start_span('Test')
          expect(ElasticAPM.current_transaction).not_to be nil
          expect(ElasticAPM.current_span).not_to be nil
        end
      end
      context 'when recording is false before the transaction is started' do
        it 'it does not create a span' do
          ElasticAPM.agent.config.recording = false
          ElasticAPM.start_transaction
          ElasticAPM.start_span('should not exist')
          expect(ElasticAPM.current_transaction).to be nil
          expect(ElasticAPM.current_span).to be nil
        end
      end
    end

    describe '.end_span' do
      it 'ends current span' do
        expect(ElasticAPM.agent).to receive(:end_span)
        ElasticAPM.end_span
      end
    end

    describe '.with_span' do
      subject do
        ElasticAPM.with_span('Block test') do
          'original result'
        end
      end

      it 'wraps block in span' do
        expect(ElasticAPM.agent).to receive(:start_span)
        expect(ElasticAPM.agent).to receive(:end_span)
        subject
      end

      it { should eq 'original result' }
    end

    it { should delegate :current_transaction, to: agent }

    it do
      should delegate :report,
        to: agent, args: ['E', { context: nil, handled: nil }]
    end
    it do
      should delegate :report_message,
        to: agent, args: ['NOT OK', { backtrace: Array, context: nil }]
    end
    it { should delegate :set_label, to: agent, args: [nil, nil] }
    it { should delegate :set_custom_context, to: agent, args: [nil] }
    it { should delegate :set_user, to: agent, args: [nil] }
    it do
      should delegate :set_destination,
        to: agent,
        args: [{address: nil, cloud: nil, port: nil, service: nil}]
    end

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

  context 'async spans', :intercept do
    context 'transaction parent' do
      it 'allows async spans' do
        with_agent do
          transaction = ElasticAPM.start_transaction
          span1 = Thread.new do
            ElasticAPM.with_span(
              'job 1',
              parent: transaction,
              sync: false
            ) { |span| span }
          end.value

          span2 = Thread.new do
            ElasticAPM.with_span(
              'job 2',
              parent: transaction,
              sync: false
            ) { |span| span }
          end.value
          transaction.done

          expect(transaction.started_spans).to eq(2)
          expect(span1.parent_id).to eq(span2.parent_id)
          expect(span1.parent_id).to eq(
            transaction.trace_context.child.parent_id
          )
          expect(span1.context.sync).to be(false)
          expect(span2.parent_id).to eq(
            transaction.trace_context.child.parent_id
          )
          expect(span2.context.sync).to be(false)
        end
      end

      context 'span created after transaction is ended' do
        it 'allows async spans' do
          with_agent do
            transaction = ElasticAPM.start_transaction
            transaction.done
            span1 = Thread.new do
              ElasticAPM.with_span(
                'job 1',
                parent: transaction,
                sync: false
              ) { |span| span }
            end.value

            span2 = Thread.new do
              ElasticAPM.with_span(
                'job 2',
                parent: transaction,
                sync: false
              ) { |span| span }
            end.value
            transaction.done

            expect(transaction.started_spans).to eq(2)
            expect(span1.parent_id).to eq(span2.parent_id)
            expect(span1.context.sync).to be(false)
            expect(span1.parent_id).to eq(
              transaction.trace_context.child.parent_id
            )
            expect(span2.context.sync).to be(false)
            expect(span2.parent_id).to eq(
              transaction.trace_context.child.parent_id
            )
          end
        end
      end

      context '#with_span' do
        it 'allows async spans' do
          with_agent do
            transaction = ElasticAPM.start_transaction
            span1 = Thread.new do
              ElasticAPM.with_span(
                'job 1',
                parent: transaction,
                sync: false
              ) { |span| span }
            end.value

            span2 = Thread.new do
              ElasticAPM.with_span('job 2', parent: transaction) { |span| span }
            end.value
            transaction.done

            expect(transaction.started_spans).to eq(2)
            expect(span1.parent_id).to eq(span2.parent_id)
            expect(span1.parent_id).to eq(
              transaction.trace_context.child.parent_id
            )
            expect(span2.parent_id).to eq(
              transaction.trace_context.child.parent_id
            )
          end
        end
      end
    end

    context 'span parent' do
      it 'allows async spans' do
        with_agent do
          transaction = ElasticAPM.start_transaction
          span1 = ElasticAPM.with_span 'run all the jobs' do |span|
            span2 = Thread.new do
              ElasticAPM.with_span('job 1', parent: span) { |s| s }
            end.value
            expect(span2.parent_id).to eq(span.trace_context.child.parent_id)
            expect(span2.context.sync).to be nil

            span3 = Thread.new do
              ElasticAPM.with_span('job 2', parent: span) { |s| s }
            end.value
            expect(span3.parent_id).to eq(span.trace_context.child.parent_id)
            expect(span3.context.sync).to be nil
            span
          end
          transaction.done

          expect(transaction.started_spans).to eq(3)
          expect(span1.parent_id).to eq(
            transaction.trace_context.child.parent_id
          )
          expect(span1.context.sync).to be nil
        end
      end
    end
  end

  context 'when not running' do
    it 'still yields block' do
      ran = false

      ElasticAPM.with_transaction { ran = true }

      expect(ran).to be true
    end
  end
end
