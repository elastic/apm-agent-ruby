# frozen_string_literal: true

require 'spec_helper'
require 'net/http'

module ElasticAPM
  RSpec.describe 'Injectors::NetHTTPInjector' do
    it 'spans http calls', :with_fake_server do
      ElasticAPM.start
      WebMock.stub_request(:get, %r{http://example.com/.*})

      transaction = ElasticAPM.transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end.submit

      expect(transaction.spans.length).to be 1

      http_span = transaction.spans.last
      expect(http_span.name).to eq 'GET example.com'

      WebMock.reset!
      ElasticAPM.stop
    end
  end
end
