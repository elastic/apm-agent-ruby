# frozen_string_literal: true

require 'net/http'

module ElasticAPM
  RSpec.describe 'Spy: NetHTTP' do
    it 'spans http calls', :intercept do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start

      ElasticAPM.with_transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'GET example.com'

      ElasticAPM.stop
      WebMock.reset!
    end
  end
end
