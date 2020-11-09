# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'spec_helper'

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
      expect(span.outcome).to eq 'success'
    end

    it 'sets span outcome to `failure` for failed operations', :intercept do
      redis = ::Redis.new

      with_agent do
        ElasticAPM.with_transaction 'Redis failure test' do
          begin
            redis.bitop("meh", "dest1", "key1")
          rescue Redis::CommandError
          end
        end
      end

      span, = @intercepted.spans

      expect(span.outcome).to eq 'failure'
    end
  end
end
