# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Middleware do
    it 'surrounds the request in a transaction', :intercept do
      ElasticAPM.start

      app = Middleware.new(->(_) { [200, {}, ['ok']] })
      status, = app.call(Rack::MockRequest.env_for('/'))
      expect(status).to be 200

      ElasticAPM.stop

      expect(@intercepted.transactions.length).to be 1

      transaction, = @intercepted.transactions
      expect(transaction.result).to eq 'HTTP 2xx'
      expect(transaction.context.response.status_code).to eq 200
    end

    it 'ignores url patterns' do
      ElasticAPM.start ignore_url_patterns: %w[/ping]

      expect(ElasticAPM).to_not receive(:start_transaction)

      app = Middleware.new(->(_) { [200, {}, ['ok']] })
      status, = app.call(Rack::MockRequest.env_for('/ping'))

      expect(status).to be 200

      ElasticAPM.stop
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

    it 'attaches a new trace_context', :intercept do
      ElasticAPM.start

      app = Middleware.new(->(_) { [200, {}, ['ok']] })

      status, = app.call(Rack::MockRequest.env_for('/'))
      expect(status).to be 200

      ElasticAPM.stop

      trace_context = @intercepted.transactions.first.trace_context
      expect(trace_context).to_not be_nil
      expect(trace_context).to be_recorded
    end

    describe 'Distributed Tracing', :intercept do
      around do |example|
        ElasticAPM.start
        example.run
        ElasticAPM.stop
      end

      let(:app) { Middleware.new(->(_) { [200, {}, ['ok']] }) }

      context 'with valid header' do
        it 'recognizes trace_context', :intercept do
          app.call(
            Rack::MockRequest.env_for(
              '/',
              'HTTP_ELASTIC_APM_TRACEPARENT' =>
              '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00'
            )
          )

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.version).to eq '00'
          expect(trace_context.trace_id)
            .to eq '0af7651916cd43dd8448eb211c80319c'
          expect(trace_context.parent_id).to eq 'b7ad6b7169203331'
          expect(trace_context).to_not be_recorded
        end
      end

      context 'with an invalid header' do
        it 'skips trace_context, makes new', :intercept do
          app.call(
            Rack::MockRequest.env_for(
              '/',
              'HTTP_ELASTIC_APM_TRACEPARENT' =>
              '00-0af7651916cd43dd8448eb211c80319c-INVALID##9203331-00'
            )
          )

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.trace_id)
            .to_not eq '0af7651916cd43dd8448eb211c80319c'
          expect(trace_context.parent_id).to_not match(/INVALID/)
        end
      end

      context 'with a blank header' do
        it 'skips trace_context, makes new', :intercept do
          app.call(
            Rack::MockRequest.env_for('/', 'HTTP_ELASTIC_APM_TRACEPARENT' => '')
          )

          trace_context = @intercepted.transactions.first.trace_context
          expect(trace_context.trace_id)
            .to_not eq '0af7651916cd43dd8448eb211c80319c'
        end
      end
    end
  end
end
