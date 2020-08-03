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

require 'elasticsearch'
require 'elastic_apm/spies/elasticsearch'

module ElasticAPM
  RSpec.describe 'Spy: Elasticsearch' do
    after { WebMock.reset! }

    it 'calls through with no transaction', :intercept do
      req_stub = WebMock.stub_request(:get, %r{http://localhost:9200/.*})

      client = Elasticsearch::Client.new log: false
      client.search q: 'test'

      expect(req_stub).to have_been_requested
    end

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
      expect(span.context.db.statement).to eq('{"params":{"q":"test"}}')

      expect(net_span.name).to eq 'GET localhost'

      destination = span.context.destination
      expect(destination.name).to eq 'elasticsearch'
      expect(destination.resource).to eq 'elasticsearch'
      expect(destination.type).to eq 'db'
    end

    context 'a post request with body' do
      before do
        WebMock.stub_request(:post, %r{http://localhost:9200/.*})
          .with(body: %r{.*})
      end

      let(:client) { Elasticsearch::Client.new log: false }

      context 'when capture_elasticsearch_queries is true' do
        it 'uses the body in the statement', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              ElasticAPM.agent.config.capture_elasticsearch_queries = true
              client.bulk(
                body: {
                  index: { _index: 'users', data: { name: 'Fernando' } }
                }
              )
            end
          end

          net_span, span = @intercepted.spans

          expect(span.name).to eq('POST _bulk')
          expect(span.context.db.statement)
            .to eq('{"params":{},"body":{"index":{"_index":"users","data":{"name":"Fernando"}}}}')
          span
        end

        it 'filters sensitive information', :intercept do
          WebMock.stub_request(:get, %r{http://localhost:9200/.*})
            .with(body: %r{.*})

          with_agent do
            ElasticAPM.with_transaction do
              ElasticAPM.agent.config.capture_elasticsearch_queries = true
              client.search(
                body: {
                  query: 'a query',
                  password: 'this is a password'
                }
              )
            end
          end

          net_span, span = @intercepted.spans

          expect(span.context.db.statement)
            .to eq('{"params":{},"body":{"query":"a query","password":"[FILTERED]"}}')
          span
        end
      end

      context 'when capture_elasticsearch_queries is false' do
        it 'does not use the body in the statement', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              ElasticAPM.agent.config.capture_elasticsearch_queries = false
              client.bulk(
                body: {
                  index: { _index: 'users', data: { name: 'Fernando' } }
                }
              )
            end
          end

          net_span, span = @intercepted.spans

          expect(span.name).to eq('POST _bulk')
          expect(span.context.db.statement)
            .to eq('{"params":{}}')
          span
        end
      end
    end
  end
end
