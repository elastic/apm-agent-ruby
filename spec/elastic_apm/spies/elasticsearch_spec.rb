# frozen_string_literal: true

require 'elasticsearch'

module ElasticAPM
  RSpec.describe 'Spy: Elasticsearch' do
    it 'spans requests', :intercept do
      WebMock.stub_request(:get, %r{http://localhost:9200/.*})

      client = Elasticsearch::Client.new log: false

      with_agent do
        ElasticAPM.with_transaction do
          client.search q: 'test'
        end
      end

      net_span, span = @intercepted.spans

      expect(span.name).to eq 'GET _search'
      expect(span.context.db.statement).to eq('{"q":"test"}')

      expect(net_span.name).to eq 'GET localhost'

      destination = span.context.destination
      expect(destination.name).to eq 'elasticsearch'
      expect(destination.resource).to eq 'elasticsearch'
      expect(destination.type).to eq 'db'
    end
  end
end
