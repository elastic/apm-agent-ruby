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
  RSpec.describe TraceContext do
    describe '.parse' do
      subject { described_class.parse(env: env) }

      context 'with a valid traceparent' do
        let(:env) do
          Rack::MockRequest.env_for(
            '/',
            'HTTP_ELASTIC_APM_TRACEPARENT' =>
            '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00'
          )
        end

        its(:traceparent) { is_expected.to be_a TraceContext::Traceparent }
      end

      context 'with an invalid traceparent' do
        let(:env) do
          Rack::MockRequest.env_for(
            '/',
            'HTTP_ELASTIC_APM_TRACEPARENT' =>
            '0asdf0-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00'
          )
        end

        it 'raises error' do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'with both traceparent and tracestate' do
        let(:env) do
          Rack::MockRequest.env_for(
            '/',
            'HTTP_ELASTIC_APM_TRACEPARENT' =>
            '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00',
            'HTTP_TRACESTATE' => 'thing=value'
          )
        end

        its(:traceparent) { is_expected.to be_a TraceContext::Traceparent }
        its(:tracestate) { is_expected.to be_a TraceContext::Tracestate }
      end

      context 'with neither' do
        let(:env) do
          Rack::MockRequest.env_for('/')
        end

        it { is_expected.to be nil }
      end

      context 'with only tracestate' do
        let(:env) do
          Rack::MockRequest.env_for(
            '/',
            'HTTP_TRACESTATE' => 'thing=value'
          )
        end

        it { is_expected.to be nil }
      end
    end

    describe '#child' do
      let(:parent) do
        described_class.new.tap do |tp|
          tp.traceparent.trace_id = '1' * 32
          tp.traceparent.id = '2' * 16
          tp.traceparent.flags = '00000011'
        end
      end

      subject { parent.child }

      it 'makes a child copy' do
        expect(subject.traceparent).to_not be parent.traceparent
      end
    end

    describe '#apply_headers' do
      subject do
        described_class.new.tap do |tp|
          tp.traceparent.trace_id = '1' * 32
          tp.traceparent.id = '2' * 16
          tp.traceparent.flags = '00000011'
        end
      end

      context 'when prefixed is disabled', :intercept do
        it 'applies only prefix-less header' do
          calls = {}
          block = ->(k, v) { calls[k] = v }

          with_agent(use_elastic_traceparent_header: false) do
            subject.apply_headers(&block)
          end

          expect(calls).to match(
            'Traceparent' => String
          )
          expect(calls.length).to be 1
        end
      end

      context 'when prefixed is enabled', :intercept do
        it 'applies both headers' do
          calls = {}
          block = ->(k, v) { calls[k] = v }

          with_agent do
            subject.apply_headers(&block)
          end

          expect(calls).to match(
            'Traceparent' => String,
            'Elastic-Apm-Traceparent' => String
          )
          expect(calls.values.uniq.length).to be 1
        end
      end

      context 'with tracestate', :intercept do
        it 'sets tracestate header' do
          calls = {}
          block = ->(k, v) { calls[k] = v }

          subject.tracestate = TraceContext::Tracestate.parse('a=b')

          with_agent do
            subject.apply_headers(&block)
          end

          expect(calls).to match(
            'Traceparent' => String,
            'Elastic-Apm-Traceparent' => String,
            'Tracestate' => 'a=b'
          )
        end
      end
    end
  end
end
