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
  RSpec.describe Instrumenter, :intercept do
    let(:config) { Config.new }
    let(:agent) { ElasticAPM.agent }

    before do
      intercept!
      ElasticAPM.start config
      allow(agent).to receive(:enqueue) { nil }
    end

    after do
      ElasticAPM.stop
    end

    subject do
      agent.instrumenter
    end

    context 'life cycle' do
      describe '#stop' do
        let(:subscriber) { double(register!: true, unregister!: true) }

        before do
          subject.subscriber = subscriber

          subject.start_transaction(config: config)
          subject.stop
        end

        its(:current_transaction) { should be_nil }

        it 'deletes thread local' do
          expect(Thread.current[ElasticAPM::Instrumenter::TRANSACTION_KEY])
            .to be_nil
        end

        it 'unregisters subscriber' do
          expect(subscriber).to have_received(:unregister!)
        end
      end

      describe 'stop and start again' do
        let(:subscriber) { double(register!: true, unregister!: true) }

        before do
          subject.subscriber = subscriber
          subject.start_transaction(config: config)
          subject.stop
        end
        after { subject.stop }

        it 're-registers the subscriber' do
          expect(subscriber).to receive(:register!)
          subject.start
        end
      end
    end

    describe '#start_transaction' do
      it 'returns a new transaction and sets it as current' do
        context = Context.new
        transaction =
          subject.start_transaction 'Test', 't',
            config: config, context: context
        expect(transaction.name).to eq 'Test'
        expect(transaction.type).to eq 't'
        expect(transaction.id).to be subject.current_transaction.id
        expect(transaction.context).to be context

        expect(subject.current_transaction).to be transaction
      end

      it 'explodes if called inside other transaction' do
        subject.start_transaction 'Test', config: config

        expect { subject.start_transaction 'Test', config: config }
          .to raise_error(ExistingTransactionError)
      end

      context 'when instrumentation is disabled' do
        let(:config) { Config.new(instrument: false) }

        it 'is nil' do
          expect(subject.start_transaction(config: config)).to be nil
          expect(subject.current_transaction).to be nil
        end
      end

      context 'with default labels' do
        let(:config) { Config.new(default_labels: { more: 'yes!' }) }

        it 'adds them to transaction context' do
          transaction = subject.start_transaction 'Test', 't', config: config
          expect(transaction.context.labels).to match(more: 'yes!')
        end
      end

      context 'with default labels' do
        let(:config) { Config.new(default_labels: { more: 'yes!' }) }

        it 'adds them to transaction context' do
          transaction = subject.start_transaction 'Test', 't', config: config
          expect(transaction.context.labels).to match(more: 'yes!')
        end
      end
    end

    describe '#end_transaction' do
      it 'is nil when no transaction' do
        expect(subject.end_transaction).to be nil
      end

      it 'ends and enqueues current transaction' do
        transaction = subject.start_transaction(config: config)
        return_value = subject.end_transaction('result')

        expect(return_value).to be transaction
        expect(transaction).to be_stopped
        expect(transaction.result).to eq 'result'
        expect(subject.current_transaction).to be nil
        expect(agent).to have_received(:enqueue).with(transaction)
      end

      it 'reports metrics', :mock_time do
        subject.start_transaction('a_transaction', config: config)
        travel 100
        subject.start_span('a_span', 'a', subtype: 'b')
        travel 100
        subject.end_span
        travel 100
        subject.end_transaction('result')

        txn_set, = agent.metrics.get(:transaction).collect

        brk_sets = agent.metrics.get(:breakdown).collect
        txn_self_time = brk_sets.find do |d|
          d.span&.fetch(:type) == 'app'
        end

        spn_self_time = brk_sets.find { |d| d.span&.fetch(:type) == 'a' }

        # txn_set
        expect(txn_set.samples[:'transaction.duration.sum.us']).to eq 300
        expect(txn_set.samples[:'transaction.duration.count']).to eq 1
        expect(txn_set.transaction).to match(
          name: 'a_transaction',
          type: 'custom'
        )
        expect(txn_set.transaction).to match(
          name: 'a_transaction',
          type: 'custom'
        )

        # txn_self_time
        expect(txn_self_time.samples[:'span.self_time.sum.us']).to eq 200
        expect(txn_self_time.samples[:'span.self_time.count']).to eq 1
        expect(txn_self_time.transaction).to match(
          name: 'a_transaction',
          type: 'custom'
        )
        expect(txn_self_time.span).to match(type: 'app', subtype: nil)

        # spn_self_time
        expect(spn_self_time.samples[:'span.self_time.sum.us']).to eq 100
        expect(spn_self_time.samples[:'span.self_time.count']).to eq 1
        expect(spn_self_time.transaction).to match(
          name: 'a_transaction',
          type: 'custom'
        )
        expect(spn_self_time.span).to match(type: 'a', subtype: 'b')

        # resets on collect
        new_txn_set, = agent.metrics.get(:transaction).collect
        expect(new_txn_set).to be nil
      end

      context 'with breakdown metrics disabled' do
        let(:config) { Config.new breakdown_metrics: false }

        it 'skips breakdown but keeps transaction metrics', :mock_time do
          subject.start_transaction('a_transaction', config: config)
          travel 100
          subject.start_span('a_span', 'a', subtype: 'b')
          travel 100
          subject.end_span
          travel 100
          subject.end_transaction('result')

          txn_sets = agent.metrics.get(:transaction).collect
          expect(txn_sets.length).to be 1

          brk_sets = agent.metrics.get(:breakdown).collect
          expect(brk_sets).to be nil
        end
      end
    end

    describe '#start_span' do
      context 'when no transaction' do
        it { expect(subject.start_span('Span')).to be nil }
      end

      context 'when transaction unsampled' do
        let(:config) { Config.new(transaction_sample_rate: 0.0) }

        it 'skips spans' do
          transaction = subject.start_transaction(config: config)
          expect(transaction).to_not be_sampled

          span = subject.start_span 'Span'
          expect(span).to be_nil
        end
      end

      context 'inside a sampled transaction' do
        let(:transaction) { subject.start_transaction(config: config) }

        before do
          transaction
        end

        it "increments transaction's span count" do
          expect { subject.start_span 'Span' }
            .to change(transaction, :started_spans).by 1
        end

        it 'starts and returns a span' do
          span = subject.start_span 'Span'

          expect(span).to be_a Span
          expect(span).to be_started
          expect(span.transaction).to eq transaction
          expect(span.parent_id).to eq transaction.id
          expect(subject.current_span).to eq span
        end

        context 'with a backtrace' do
          it 'saves original backtrace for later' do
            backtrace = caller
            span = subject.start_span 'Span', backtrace: backtrace
            expect(span.original_backtrace).to eq backtrace
          end
        end

        context 'inside another span' do
          it 'sets current span as parent' do
            parent = subject.start_span 'Level 1'
            child = subject.start_span 'Level 2'

            expect(child.parent_id).to be parent.id
          end
        end

        context 'when max spans reached' do
          let(:config) { Config.new(transaction_max_spans: 1) }
          before do
            2.times do |i|
              subject.start_span i.to_s
              subject.end_span
            end
          end

          it "increments transaction's span count, returns nil" do
            expect do
              expect(subject.start_span('Span')).to be nil
            end.to change(transaction, :started_spans).by 1
          end
        end
      end
    end

    describe '#end_span' do
      context 'when missing span' do
        before { subject.start_transaction(config: config) }
        it { expect(subject.end_span).to be nil }
      end

      context 'inside transaction and span' do
        let(:transaction) { subject.start_transaction(config: config) }
        let(:span) { subject.start_span 'Span' }

        before do
          transaction
          span
        end

        it 'closes span, sets new current, enqueues' do
          return_value = subject.end_span

          expect(return_value).to be span
          expect(span).to be_stopped
          expect(subject.current_span).to be nil
          expect(agent).to have_received(:enqueue).with(span)
        end

        context 'inside another span' do
          it 'sets current span to parent' do
            nested = subject.start_span 'Nested'

            return_value = subject.end_span

            expect(return_value).to be nested
            expect(subject.current_span).to be span
          end
        end

        context 'when passing a span' do
          let(:another_span) { subject.start_span 'Another Span' }

          before do
            another_span
          end

          it 'closes span, sets new current, enqueues' do
            return_value = subject.end_span(span)

            expect(return_value).to be span
            expect(span).to be_stopped
            expect(subject.current_span).to be another_span
            expect(agent).to have_received(:enqueue).with(span)
          end
        end
      end
    end

    describe '#set_label' do
      it 'sets tag on current transaction' do
        transaction = subject.start_transaction 'Test', config: config
        subject.set_label :things, 'are all good!'

        expect(transaction.context.labels).to match(things: 'are all good!')
      end

      it 'de-dots keys' do
        transaction = subject.start_transaction 'Test', config: config
        subject.set_label 'th.ings', 'are all good!'
        subject.set_label 'thi"ngs', 'are all good!'
        subject.set_label 'thin*gs', 'are all good!'

        expect(transaction.context.labels).to match(
          th_ings: 'are all good!',
          thi_ngs: 'are all good!',
          thin_gs: 'are all good!'
        )
      end

      it 'allows boolean values' do
        transaction = subject.start_transaction 'Test', config: config
        subject.set_label :things, true

        expect(transaction.context.labels).to match(things: true)
      end

      it 'allows numerical values' do
        transaction = subject.start_transaction 'Test', config: config
        subject.set_label :things, 123

        expect(transaction.context.labels).to match(things: 123)
      end
    end

    describe '#set_custom_context' do
      it 'sets custom context on transaction' do
        transaction = subject.start_transaction 'Test', config: config
        subject.set_custom_context(one: 'is in', two: 2, three: false)

        expect(transaction.context.custom).to match(
          one: 'is in',
          two: 2,
          three: false
        )
      end
    end

    describe '#set_user' do
      User = Struct.new(:id, :email, :username)

      it 'sets user in context' do
        transaction = subject.start_transaction 'Test', config: config
        subject.set_user(User.new(1, 'a@a', 'abe'))
        subject.end_transaction

        user = transaction.context.user
        expect(user.id).to eq '1'
        expect(user.email).to eq 'a@a'
        expect(user.username).to eq 'abe'
      end
    end

    describe '#handle_forking!' do
      let(:subscriber) { double(register!: true, unregister!: true) }
      it 'restarts with the subscriber still registered' do
        subject.start
        subject.subscriber = subscriber

        expect(subscriber).to receive(:register!)
        subject.handle_forking!

        subject.stop
      end
    end
  end
end
