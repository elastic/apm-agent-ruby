# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Middleware do
    it 'surrounds the request in a transaction' do
      ElasticAPM.start Config.new

      expect(ElasticAPM).to receive(:transaction).and_call_original

      app = Middleware.new(->(_) { [200, {}, ['ok']] })
      status, = app.call(Rack::MockRequest.env_for('/'))

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
        .with(MiddlewareTestError, rack_env: Hash, handled: false)
    end
  end
end
