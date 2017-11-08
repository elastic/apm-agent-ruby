# frozen_string_literal: true

require 'spec_helper'

require 'redis'
require 'fakeredis'
require 'elastic_apm/injectors/redis'

module ElasticAPM
  RSpec.describe 'Redis tracing' do
    it 'traces queries' do
      redis = ::Redis.new
      ElasticAPM.start Config.new

      transaction = ElasticAPM.transaction 'T' do
        redis.lrange('some:where', 0, -1)
      end

      expect(transaction.traces.length).to be 1
      expect(transaction.traces.last.name).to eq 'lrange'

      ElasticAPM.stop
    end
  end
end
