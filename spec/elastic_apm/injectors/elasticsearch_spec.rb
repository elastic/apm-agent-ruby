# frozen_string_literal: true

require 'spec_helper'

require 'elasticsearch'
require 'elastic_apm/injectors/elasticsearch'

module ElasticAPM
  RSpec.describe Injectors::ElasticsearchInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['elasticsearch-transport'] ||   # when missing
        Injectors.installed['Elasticsearch::Transport::Client'] # when present

      expect(registration.injector).to be_a described_class
    end

    it 'spans requests' do
      ElasticAPM.start(enabled_injectors: %w[elasticsearch])
      WebMock.stub_request(:get, %r{http://localhost:9200/.*})

      client = Elasticsearch::Client.new log: false

      transaction = ElasticAPM.transaction 'T' do
        client.search q: 'test'
      end

      span = transaction.spans.last
      expect(span.name).to eq 'GET _search'
      expect(span.context.statement).to eq(q: 'test')

      WebMock.reset!
      ElasticAPM.stop
    end
  end
end
