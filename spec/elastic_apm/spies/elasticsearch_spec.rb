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

require 'elasticsearch'

module ElasticAPM
  RSpec.describe 'Spy: Elasticsearch' do
    after { WebMock.reset! }

    it 'spans requests', :intercept do
      WebMock.stub_request(:get, %r{http://localhost:9200/.*})

      client = Elasticsearch::Client.new log: false

      with_agent do
        ElasticAPM.with_transaction do
          client.search q: 'test'
        end
      end

      net_span, span = @intercepted.spans

      expect(span.name).to eq 'GET _search'
      expect(span.context.db.statement).to eq('{"q":"test"}')

      expect(net_span.name).to eq 'GET localhost'

      destination = span.context.destination
      expect(destination.name).to eq 'elasticsearch'
      expect(destination.resource).to eq 'elasticsearch'
      expect(destination.type).to eq 'db'
    end
  end
end
