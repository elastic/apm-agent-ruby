# frozen_string_literal: true

require 'elasticsearch'

module ElasticAPM
  RSpec.describe 'Spy: Elasticsearch' do
    it 'spans requests' do
      ElasticAPM.start disable_send: true
      WebMock.stub_request(:get, %r{http://localhost:9200/.*})

      client = Elasticsearch::Client.new log: false

      transaction = ElasticAPM.transaction 'T' do
        client.search q: 'test'
      end

      span, net_span = transaction.spans

      expect(span.name).to eq 'GET _search'
      expect(span.context.statement).to eq('{"q":"test"}')

      expect(net_span.name).to eq 'GET localhost'

      WebMock.reset!
      ElasticAPM.stop
    end
  end
end
