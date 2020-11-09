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
  RSpec.describe Middleware, :intercept do
    it 'surrounds the request in a transaction' do
      with_agent do
        app = Middleware.new(->(_) { [200, {}, ['ok']] })
        status, = app.call(Rack::MockRequest.env_for('/'))
        expect(status).to be 200
      end

      expect(@intercepted.transactions.length).to be 1

      transaction, = @intercepted.transactions
      expect(transaction.result).to eq 'HTTP 2xx'
      expect(transaction.context.response.status_code).to eq 200
      expect(transaction.outcome).to eq 'success'
    end

    it 'ignores url patterns' do
      with_agent transaction_ignore_urls: %w[/status/*/ping] do
        expect(ElasticAPM).to_not receive(:start_transaction)

        app = Middleware.new(->(_) { [200, {}, ['ok']] })
        status, = app.call(Rack::MockRequest.env_for('/status/something/ping'))

        expect(status).to be 200
      end
    end

    it 'catches exceptions' do
      class MiddlewareTestError < StandardError; end

      allow(ElasticAPM).to receive(:report)

      app = Middleware.new(lambda do |*_|
        raise MiddlewareTestError, 'Yikes!'
      end)

      expect do
        app.call(Rack::MockRequest.env_for('/'))
      end.to raise_error(MiddlewareTestError)

      expect(ElasticAPM).to have_received(:report)
        .with(MiddlewareTestError, context: nil, handled: false)
    end

    it 'attaches a new trace_context' do
      with_agent do
        app = Middleware.new(->(_) { [200, {}, ['ok']] })

        status, = app.call(Rack::MockRequest.env_for('/'))
        expect(status).to be 200
      end

      trace_context = @intercepted.transactions.first.trace_context
      expect(trace_context).to_not be_nil
      expect(trace_context).to be_recorded
      expect(trace_context.tracestate.sample_rate).to_not be nil
    end

    it 'sets outcome to `failure` for http status code >= 500', :intercept do
      with_agent do
        app = Middleware.new(->(_) { [500, {}, ['Internal Server Error']] })
        app.call(Rack::MockRequest.env_for('/'))
      end

      expect(@intercepted.transactions.length).to be 1

      transaction, = @intercepted.transactions
      expect(transaction.result).to eq 'HTTP 5xx'
      expect(transaction.context.response.status_code).to eq 500
      expect(transaction.outcome).to eq 'failure'
    end

    it 'sets outcome to `failure` for failed requests', :intercept do
      class MiddlewareTestError < StandardError; end

      app = Middleware.new(lambda do |*_|
        raise MiddlewareTestError, 'Yikes!'
      end)

      expect do
        with_agent do
          app.call(Rack::MockRequest.env_for('/'))
        end
      end.to raise_error(MiddlewareTestError)

      transaction, = @intercepted.transactions
      expect(transaction.outcome).to eq 'failure'
    end

    describe 'Distributed Tracing' do
      let(:app) { Middleware.new(->(_) { [200, {}, ['ok']] }) }

      context 'with valid header' do
        it 'recognizes trace_context' do
          with_agent do
            app.call(
              Rack::MockRequest.env_for(
                '/',
                'HTTP_ELASTIC_APM_TRACEPARENT' =>
                '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00'
              )
            )
          end

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.version).to eq '00'
          expect(trace_context.trace_id)
            .to eq '0af7651916cd43dd8448eb211c80319c'
          expect(trace_context.parent_id).to eq 'b7ad6b7169203331'
          expect(trace_context).to_not be_recorded
        end
      end

      context 'with tracestate' do
        it 'recognizes trace_context' do
          with_agent do
            app.call(
              Rack::MockRequest.env_for(
                '/',
                'HTTP_ELASTIC_APM_TRACEPARENT' =>
                '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00',
                'HTTP_TRACESTATE' => 'es=s:0.75,abc=123'
              )
            )
          end

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.tracestate).to be_a(TraceContext::Tracestate)
          expect(trace_context.tracestate.to_header).to match('es=s:0.75,abc=123')
        end
      end

      context 'with an invalid header' do
        it 'skips trace_context, makes new' do
          with_agent do
            app.call(
              Rack::MockRequest.env_for(
                '/',
                'HTTP_ELASTIC_APM_TRACEPARENT' =>
                '00-0af7651916cd43dd8448eb211c80319c-INVALID##9203331-00'
              )
            )
          end

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.trace_id)
            .to_not eq '0af7651916cd43dd8448eb211c80319c'
          expect(trace_context.parent_id).to_not match(/INVALID/)
        end
      end

      context 'with a blank header' do
        it 'skips trace_context, makes new' do
          with_agent do
            app.call(
              Rack::MockRequest.env_for(
                '/', 'HTTP_ELASTIC_APM_TRACEPARENT' => ''
              )
            )
          end

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.trace_id)
            .to_not eq '0af7651916cd43dd8448eb211c80319c'
        end
      end

      context 'with a prefix-less header' do
        it 'recognizes trace_context' do
          with_agent do
            app.call(
              Rack::MockRequest.env_for(
                '/',
                'HTTP_TRACEPARENT' =>
                '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00'
              )
            )
          end

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.version).to eq '00'
          expect(trace_context.trace_id)
            .to eq '0af7651916cd43dd8448eb211c80319c'
          expect(trace_context.parent_id).to eq 'b7ad6b7169203331'
          expect(trace_context).to_not be_recorded
        end
      end

      context 'with both types of headers' do
        it 'picks the prefixed' do
          with_agent do
            app.call(
              Rack::MockRequest.env_for(
                '/',
                'HTTP_TRACEPARENT' =>
                '00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-aaaaaaaaaaaaaaaa-00',
                'HTTP_ELASTIC_APM_TRACEPARENT' =>
                '00-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-bbbbbbbbbbbbbbbb-00'
              )
            )
          end

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.version).to eq '00'
          expect(trace_context.trace_id)
            .to eq 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          expect(trace_context.parent_id).to eq 'bbbbbbbbbbbbbbbb'
          expect(trace_context).to_not be_recorded
        end
      end
    end

    describe 'deprecated' do
      it 'ignores url patterns' do
        allow_any_instance_of(Config).to receive(:warn).with(/DEPRECATED/) { nil }

        with_agent ignore_url_patterns: %w[/ping] do
          expect(ElasticAPM).to_not receive(:start_transaction)

          app = Middleware.new(->(_) { [200, {}, ['ok']] })
          status, = app.call(Rack::MockRequest.env_for('/ping'))

          expect(status).to be 200
        end
      end
    end
  end
end
