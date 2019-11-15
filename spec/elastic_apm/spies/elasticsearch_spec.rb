# frozen_string_literal: true

require 'elasticsearch'

module ElasticAPM
  RSpec.describe 'Spy: Elasticsearch' do
    let(:client) do
      Elasticsearch::Client.new log: false
    end

    let(:span) do
      @intercepted.spans[1]
    end

    let(:net_span) do
      @intercepted.spans[0]
    end

    before do
      WebMock.stub_request(:get, %r{http://localhost:9200/.*})
      with_agent do
        ElasticAPM.with_transaction do
          client.search q: 'test'
        end
      end
    end

    after do
      WebMock.reset!
    end

    it 'spans requests', :intercept do
      expect(span.name).to eq 'GET _search'
      expect(span.context.db.statement).to eq('{"q":"test"}')
      expect(net_span.name).to eq 'GET localhost'
    end
  end
end
