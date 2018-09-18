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
        .with(MiddlewareTestError, handled: false)
    end
  end
end
