# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Middleware do
    it 'surrounds the request in a transaction' do
      ElasticAPM.start Config.new

      mock_transaction = double(Transaction, release: true, submit: true)
      allow(ElasticAPM).to receive(:transaction) { mock_transaction }

      app = Middleware.new(->(_) { [200, {}, ['ok']] })
      status, = app.call(Rack::MockRequest.env_for('/'))

      expect(status).to be 200
      expect(mock_transaction).to have_received(:release)
      expect(mock_transaction).to have_received(:submit)

      ElasticAPM.stop
    end
  end
end
