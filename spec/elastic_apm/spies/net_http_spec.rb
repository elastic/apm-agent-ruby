# frozen_string_literal: true

require 'net/http'

module ElasticAPM
  RSpec.describe 'Spy: NetHTTP' do
    it 'spans http calls' do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start disable_send: true

      transaction = ElasticAPM.transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end.submit

      expect(transaction.spans.length).to be 1

      http_span = transaction.spans.last
      expect(http_span.name).to eq 'GET example.com'

      ElasticAPM.stop
      WebMock.reset!
    end
  end
end
