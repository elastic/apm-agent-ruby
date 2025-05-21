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

      context 'when the transaction is unsampled' do
        let(:config) { Config.new }
        it 'sets the sample rate to 0' do
          expect(subject).to receive(:random_sample?) { false }
          t = subject.start_transaction 'Test', 't', config: config
          expect(t.sampled?).to be false
          expect(t.sample_rate).to eq 0
        end
      end

      context 'when the transaction is sampled' do
        let(:config) { Config.new(transaction_sample_rate: '0.2') }
        it 'sets the sample rate to the configured sample rate' do
          expect(subject).to receive(:random_sample?) { true }
          t = subject.start_transaction 'Test', 't', config: config
          expect(t.sampled?).to be true
          expect(t.sample_rate).to eq 0.2
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

      it 'reports metrics' do
        agent.metrics.stop
        subject.start_transaction('a_transaction', config: config)
        sleep(0.1)
        subject.start_span('a_span', 'a', subtype: 'b')
        sleep(0.1)
        subject.end_span
        sleep(0.1)
        subject.end_transaction('result')

        brk_sets = agent.metrics.get(:breakdown).collect
        txn_self_time = brk_sets.find do |d|
          d.span&.fetch(:type) == 'app'
        end

        spn_self_time = brk_sets.find { |d| d.span&.fetch(:type) == 'a' }

        # txn_self_time
        expect(txn_self_time.samples[:'span.self_time.sum.us']).to be > 200000
        expect(txn_self_time.samples[:'span.self_time.count']).to eq 1
        expect(txn_self_time.transaction).to match(
          name: 'a_transaction',
          type: 'custom'
        )
        expect(txn_self_time.span).to match(type: 'app', subtype: nil)

        # spn_self_time
        expect(spn_self_time.samples[:'span.self_time.sum.us']).to be > 100000
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

        context "with an exit_span parent" do
          it "is nil" do
            parent = subject.start_span('Parent', exit_span: true)

            span = subject.start_span('Inside')
            expect(span).to be nil

            subject.end_span(parent)
          end

          it 'makes a subspan if type/subtype matches' do
            parent = subject.start_span('Parent', 'my_type', exit_span: true)

            span = subject.start_span('Inside', 'my_type')
            expect(span).to_not be nil

            subject.end_span(parent)
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

    describe 'unsampled transactions' do
      let(:config) { Config.new(transaction_sample_rate: '0') }

      context 'when the server version is less than 8.0' do
        it 'enqueues the transaction' do
          stub_request(:get, "http://localhost:8200/")
            .to_return(status: 200, body: '{"version": "7.17.4"}')
          expect(subject.enqueue).to receive(:call).and_call_original
          subject.start_transaction 'Test', config: config
          subject.end_transaction
        end
      end

      context 'when the server version is at least 8.0' do
        it 'does not enqueue the transaction' do
          stub_request(:get, "http://localhost:8200/")
            .to_return(status: 200, body: '{"version": "8.5.3"}')
          expect(subject.enqueue).not_to receive(:call)
          subject.start_transaction 'Test', config: config
          subject.end_transaction
        end
      end
    end

    describe '#transaction_sample_rate_for_name' do
      let(:default_rate) { 0.5 }
      let(:special_rate) { 1.0 }

      context 'with nil name' do
        it 'returns nil' do
          config = Config.new(transaction_sample_rate: default_rate)
          expect(subject.transaction_sample_rate_for_name(nil, config)).to be_nil
        end
      end

      context 'with empty transaction_sample_rate_by_name' do
        it 'returns nil' do
          config = Config.new(transaction_sample_rate_by_name: {})
          expect(subject.transaction_sample_rate_for_name('Something', config)).to be_nil
        end
      end

      context 'with matching name in transaction_sample_rate_by_name' do
        it 'returns matching sample rate' do
          config = Config.new(
            transaction_sample_rate: default_rate,
            transaction_sample_rate_by_name: { 'Something' => special_rate }
          )
          expect(subject.transaction_sample_rate_for_name('Something', config)).to eq(special_rate)
        end
      end

      context 'with non-matching name in transaction_sample_rate_by_name' do
        it 'returns default sample rate' do
          config = Config.new(
            transaction_sample_rate_by_name: { 'SomethingElse' => special_rate }
          )
          expect(subject.transaction_sample_rate_for_name('Something', config)).to be_nil
        end
      end
    end

    describe 'span-based sampling' do
      context 'when starting a span with a name that has a different sampling rate' do
        it 'can change the sampling decision of the transaction' do
          config = Config.new(
            transaction_sample_rate: 0.0,
            transaction_sample_rate_by_name: { 'ImportantOperation' => 1.0 }
          )

          # Force predictable random sampling
          allow(subject).to receive(:rand).and_return(0.5)

          transaction = subject.start_transaction('Test', config: config)
          expect(transaction).not_to be_sampled

          # Verify sampling is updated when first span is created
          allow(subject).to receive(:random_sample?).and_return(true)
          span = subject.start_span('ImportantOperation')

          # The span should exist (since the transaction is now sampled)
          expect(span).not_to be_nil
          expect(transaction).to be_sampled
        end

        it 'only considers the first span for changing the sampling decision' do
          config = Config.new(
            transaction_sample_rate: 0.0,
            transaction_sample_rate_by_name: {
              'FirstSpan' => 1.0,
              'SecondSpan' => 0.0,
              'ThirdSpan' => 0.5
            }
          )

          # Force predictable random sampling
          allow(subject).to receive(:rand).and_return(0.5)

          transaction = subject.start_transaction('Test', config: config)
          expect(transaction).not_to be_sampled

          # First span changes sampling because it's the first span
          first_span = subject.start_span('FirstSpan')
          expect(first_span).not_to be_nil
          expect(transaction).to be_sampled
          expect(transaction.sample_rate).to eq(1.0)

          # Initial sampling rate stored
          original_sample_rate = transaction.sample_rate

          # Second span should not change sampling even though it has a different rate
          second_span = subject.start_span('SecondSpan')
          expect(second_span).not_to be_nil
          expect(transaction.sample_rate).to eq(original_sample_rate)

          # Third span should not change sampling either
          third_span = subject.start_span('ThirdSpan')
          expect(third_span).not_to be_nil
          expect(transaction.sample_rate).to eq(original_sample_rate)
        end
      end
    end
  end
end
