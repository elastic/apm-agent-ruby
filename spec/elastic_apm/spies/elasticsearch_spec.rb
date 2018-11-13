# frozen_string_literal: true

require 'elasticsearch'

module ElasticAPM
  RSpec.describe 'Spy: Elasticsearch' do
    it 'spans requests', :intercept do
      ElasticAPM.start
      WebMock.stub_request(:get, %r{http://localhost:9200/.*})

      client = Elasticsearch::Client.new log: false

      ElasticAPM.with_transaction do
        client.search q: 'test'
      end

      net_span, span = @intercepted.spans

      expect(span.name).to eq 'GET _search'
      expect(span.context.db.statement).to eq('{"q":"test"}')

      expect(net_span.name).to eq 'GET localhost'

      WebMock.reset!
      ElasticAPM.stop
    end
  end
end
