# frozen_string_literal: true

require 'fakeredis/rspec'

module ElasticAPM
  RSpec.describe 'Spy: Redis' do
    it 'spans queries', :intercept do
      redis = ::Redis.new

      with_agent do
        ElasticAPM.with_transaction 'T' do
          redis.lrange('some:where', 0, -1)
        end
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'LRANGE'
    end
  end
end
