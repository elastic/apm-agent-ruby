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

require 'integration_helper'

require 'elastic_apm/opentracing'

RSpec.describe 'OpenTracing bridge', :intercept do
  let(:tracer) { ::OpenTracing.global_tracer }

  before :context do
    ::OpenTracing.global_tracer = ElasticAPM::OpenTracing::Tracer.new
  end

  context 'without an agent' do
    it 'is a noop' do
      thing = double(ran: 'success')

      result = tracer.start_active_span('namest') do |scope|
        expect(scope).to be_a ElasticAPM::OpenTracing::Scope

        tracer.start_active_span('nested') do |nested_scope|
          expect(nested_scope.span).to be ::OpenTracing::Span::NOOP_INSTANCE

          thing.ran('…')
        end
      end

      expect(thing).to have_received(:ran).with('…')
      expect(result).to eq 'success'
    end
  end

  context 'with an APM Agent' do
    before do
      intercept!
      ElasticAPM.start
    end
    after { ElasticAPM.stop }

    describe '#start_span' do
      context 'as root' do
        subject! { ::OpenTracing.start_span('namest') }
        after { subject.finish }

        it { should be_an ElasticAPM::OpenTracing::Span }
        its(:elastic_span) { should be_an ElasticAPM::Transaction }
        its(:context) { should be_an ElasticAPM::OpenTracing::SpanContext }

        it 'is not active' do
          expect(::OpenTracing.active_span).to be nil
        end
      end

      context 'as a child' do
        let(:parent) { ::OpenTracing.start_span('parent') }
        subject! { ::OpenTracing.start_span('namest', child_of: parent) }
        after do
          subject.finish
          parent.finish
        end

        it 'has a child context' do
          expect(subject.context.parent_id).to eq parent.context.id
          expect(subject.context.id).not_to eq parent.context.id
          expect(subject.context.trace_id).to eq parent.context.trace_id
        end

        its(:elastic_span) { should be_a ElasticAPM::Span }
      end
    end

    describe '#start_active_span' do
      context 'as root' do
        subject! { ::OpenTracing.start_active_span('namest') }
        after { subject.close }

        it { should be_an ElasticAPM::OpenTracing::Scope }
        its(:elastic_span) { should be_a ElasticAPM::Transaction }

        it 'is active' do
          expect(::OpenTracing.active_span).to be subject.span
        end
      end

      context 'as child_of' do
        let(:parent) { ::OpenTracing.start_span('parent') }
        subject! { ::OpenTracing.start_active_span('namest', child_of: parent) }
        after do
          subject.close
          parent.finish
        end

        it 'is the correct span' do
          expect(subject.span.elastic_span).to be_an ElasticAPM::Span
        end

        it 'is active' do
          expect(::OpenTracing.active_span).to be subject.span
        end
      end

      context 'when a block is passed' do
        it 'returns the result of the block' do
          thing = double(ran: 'success')

          result = tracer.start_active_span('namest') do
            thing.ran('…')
          end

          expect(thing).to have_received(:ran).with('…')
          expect(result).to eq 'success'
        end
      end
    end

    describe 'activation' do
      it 'sets the span as active in scope' do
        span = OpenTracing.start_span('name')
        scope = OpenTracing.scope_manager.activate(span)
        expect(OpenTracing.active_span).to be span

        scope.close
      end
    end

    describe '#inject' do
      let(:context) do
        ElasticAPM::TraceContext.new(
          traceparent: ElasticAPM::TraceContext::Traceparent.parse(
            '00-11111111111111111111111111111111-2222222222222222-00'
          )
        )
      end
      let(:carrier) { {} }

      subject { ::OpenTracing.inject(context, format, carrier) }

      context 'Rack' do
        let(:format) { ::OpenTracing::FORMAT_RACK }

        it 'sets a header' do
          subject
          expect(carrier['elastic-apm-traceparent'])
            .to eq context.traceparent.to_header
        end
      end

      context 'Text map' do
        let(:format) { ::OpenTracing::FORMAT_TEXT_MAP }

        it 'sets a header' do
          subject
          expect(carrier['elastic-apm-traceparent'])
            .to eq context.traceparent.to_header
        end
      end

      context 'Binary' do
        let(:format) { ::OpenTracing::FORMAT_BINARY }

        it 'warns about lack of support' do
          expect(tracer).to receive(:warn).with(/Only injection via/)
          subject
        end
      end
    end

    describe '#extract' do
      subject { ::OpenTracing.extract(format, carrier) }

      context 'Rack' do
        let(:format) { ::OpenTracing::FORMAT_RACK }
        let(:carrier) do
          { 'HTTP_ELASTIC_APM_TRACEPARENT' =>
              '00-11111111111111111111111111111111-2222222222222222-00' }
        end

        it 'returns a span context' do
          expect(subject).to be_a ElasticAPM::OpenTracing::SpanContext
          expect(subject.trace_context.trace_id)
            .to eq '11111111111111111111111111111111'
          expect(subject.trace_context.id).to eq '2222222222222222'
          expect(subject.trace_context.parent_id).to be_nil
        end
      end

      context 'Text map' do
        let(:format) { ::OpenTracing::FORMAT_TEXT_MAP }
        let(:carrier) do
          { 'elastic-apm-traceparent' =>
              '00-11111111111111111111111111111111-2222222222222222-00' }
        end

        it 'returns a span context' do
          expect(subject).to be_a ElasticAPM::OpenTracing::SpanContext
          expect(subject.trace_context.trace_id)
            .to eq '11111111111111111111111111111111'
          expect(subject.trace_context.id).to eq '2222222222222222'
          expect(subject.trace_context.parent_id).to be_nil
        end
      end

      context 'Binary' do
        let(:format) { ::OpenTracing::FORMAT_BINARY }
        let(:carrier) { {} }

        it 'warns about lack of support' do
          expect(tracer).to receive(:warn).with(/Only extraction from/)
          subject
        end
      end
    end
  end

  describe 'example', :intercept do
    before do
      intercept!
      ElasticAPM.start
    end
    after { ElasticAPM.stop }

    matcher :be_a_child_of do |parent_scope|
      match do |scope|
        scope.span.context.parent_id == parent_scope.span.context.id
      end
    end

    it 'traces nested spans' do
      OpenTracing.start_active_span(
        'operation_name',
        tags: { test: '0' }
      ) do |scope|
        expect(scope).to be_a(ElasticAPM::OpenTracing::Scope)
        expect(OpenTracing.active_span).to be scope.span
        expect(OpenTracing.active_span).to be_a ElasticAPM::OpenTracing::Span

        OpenTracing.start_active_span(
          'nested',
          tags: { test: '1' }
        ) do |nested_scope|
          expect(OpenTracing.active_span).to be nested_scope.span
          expect(nested_scope).to be_a_child_of scope

          OpenTracing.start_active_span('namest') do |further_nested|
            expect(OpenTracing.active_span).to be further_nested.span
            expect(further_nested).to_not be nested_scope
            expect(further_nested).to be_a_child_of nested_scope
          end
        end
      end

      expect(@intercepted.transactions.length).to be 1
      expect(@intercepted.spans.length).to be 2

      transaction, = @intercepted.transactions
      expect(transaction.context.labels).to match(test: '0')

      span = @intercepted.spans.last
      expect(span.context.labels).to match(test: '1')
    end
  end

  describe ElasticAPM::OpenTracing::Span do
    before do
      intercept!
      ElasticAPM.start
    end
    after { ElasticAPM.stop }

    let(:elastic_span) do
      ElasticAPM::Transaction.new config: ElasticAPM::Config.new
    end

    describe 'log_kv' do
      subject { described_class.new(elastic_span, nil) }

      it 'logs exceptions' do
        subject.log_kv('error.object': actual_exception)
        expect(@intercepted.errors.length).to be 1
      end

      it 'logs messages' do
        subject.log_kv(message: 'message')
        expect(@intercepted.errors.length).to be 1
      end

      it 'ignores unknown logs' do
        subject.log_kv(other: 1)
        expect(@intercepted.errors.length).to be 0
      end
    end

    describe 'set_tag' do
      subject { described_class.new(elastic_span, trace_context) }

      shared_examples :opengraph_span do
        it 'can set operation name' do
          subject.operation_name = 'Test'
          expect(elastic_span.name).to eq 'Test'
        end

        describe 'set_tag' do
          it 'sets elastic span label' do
            subject.set_tag :custom_key, 'custom_type'
            expect(subject.elastic_span.context.labels[:custom_key])
              .to eq 'custom_type'
          end

          it 'returns self' do
            expect(subject.set_tag(:custom_key, 'custom_type'))
              .to be_a ElasticAPM::OpenTracing::Span
          end
        end
      end

      context 'when transaction' do
        let(:elastic_span) do
          ElasticAPM::Transaction.new config: ElasticAPM::Config.new
        end
        let(:trace_context) { nil }

        it_behaves_like :opengraph_span

        it 'knows user fields' do
          subject.set_tag 'user.id', 1
          subject.set_tag 'user.username', 'someone'
          subject.set_tag 'user.email', 'someone@example.com'
          subject.set_tag 'user.other_field', 'someone@example.com'

          user = subject.elastic_span.context.user
          expect(user.id).to eq 1
          expect(user.username).to eq 'someone'
          expect(user.email).to eq 'someone@example.com'
        end
      end

      context 'when span' do
        let(:elastic_span) do
          transaction =
            ElasticAPM::Transaction.new(config: ElasticAPM::Config.new)

          ElasticAPM::Span.new(
            name: 'Span',
            transaction: transaction,
            parent: transaction,
            trace_context: trace_context
          )
        end
        let(:trace_context) { nil }

        it_behaves_like :opengraph_span

        it "doesn't explode on user fields" do
          expect { subject.set_tag 'user.id', 1 }
            .to_not raise_error
        end
      end
    end

    describe '#finish' do
      subject do
        ::OpenTracing.start_span(
          'namest',
          start_time: Time.new(2020, 1, 1, 0, 0, 1)
        )
      end

      context 'when the span is finished with a `Time` as end_time' do
        before { subject.finish(end_time: Time.new(2020, 1, 1, 0, 0, 2)) }

        it 'converts to monotonic time' do
          expect(subject.elastic_span.duration).to eq(1_000_000)
        end
      end
    end
  end
end
