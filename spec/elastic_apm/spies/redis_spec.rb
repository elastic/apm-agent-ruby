# frozen_string_literal: true

require 'fakeredis/rspec'

module ElasticAPM
  RSpec.describe 'Spy: Redis' do
    include_context 'intercept'

    it 'spans queries' do
      redis = ::Redis.new
      ElasticAPM.start

      ElasticAPM.with_transaction 'T' do
        redis.lrange('some:where', 0, -1)
      end

      span, = intercepted.spans

      expect(span.name).to eq 'LRANGE'

      ElasticAPM.stop
    end
  end
end
