# frozen_string_literal: true

require 'spec_helper'

require 'redis'
require 'fakeredis'

require 'elastic_apm/injectors/redis'

module ElasticAPM
  RSpec.describe Injectors::RedisInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['redis'] || # when missing
        Injectors.installed['Redis']        # when present

      expect(registration.injector).to be_a described_class
    end

    it 'spans queries' do
      redis = ::Redis.new
      ElasticAPM.start Config.new(enabled_injectors: %w[redis])

      transaction = ElasticAPM.transaction 'T' do
        redis.lrange('some:where', 0, -1)
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'lrange'

      ElasticAPM.stop
    end
  end
end
