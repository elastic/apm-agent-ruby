# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Middleware do
    it 'surrounds the request in a transaction', :mock_intake do
      ElasticAPM.start

      expect(ElasticAPM).to receive(:transaction).and_call_original

      app = Middleware.new(->(_) { [200, {}, ['ok']] })
      status, = app.call(Rack::MockRequest.env_for('/'))

      expect(status).to be 200

      ElasticAPM.stop

      expect(@mock_intake.requests.length).to be 1

      payload = @mock_intake.transactions.last
      expect(payload['result']).to eq 'HTTP 2xx'
      expect(payload.dig('context', 'response', 'status_code')).to be 200
    end

    it 'ignores url patterns' do
      ElasticAPM.start ignore_url_patterns: %w[/ping]

      expect(ElasticAPM).to_not receive(:transaction)

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
