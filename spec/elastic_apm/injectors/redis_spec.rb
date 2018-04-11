# frozen_string_literal: true

require 'spec_helper'

require 'redis'
require 'fakeredis'

module ElasticAPM
  RSpec.describe 'Injectors::RedisInjector' do
    it 'spans queries' do
      redis = ::Redis.new
      ElasticAPM.start

      transaction = ElasticAPM.transaction 'T' do
        redis.lrange('some:where', 0, -1)
      end.submit 200

      expect(transaction.spans.length).to be 1
      span = transaction.spans.last
      expect(span.name).to eq 'LRANGE'

      ElasticAPM.stop
    end
  end
end
