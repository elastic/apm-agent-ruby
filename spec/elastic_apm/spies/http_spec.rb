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

require 'http'

module ElasticAPM
  RSpec.describe 'Spy: HTTP.rb', :intercept do
    it 'spans http calls' do
      WebMock.stub_request(:get, %r{http://example.com/.*})

      with_agent do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.name).to eq 'GET example.com'
      expect(span.outcome).to eq 'success'
    end

    it 'adds http context' do
      WebMock.stub_request(:get, %r{http://example.com/.*})

      with_agent do
        ElasticAPM.with_transaction 'Http.rb test' do
          HTTP.get('http://example.com/page.html')
        end
      end

      span, = @intercepted.spans

      http = span.context.http
      expect(http.url).to match('http://example.com/page.html')
      expect(http.method).to match('GET')
      expect(http.status_code).to match('200')
    end

    it 'adds destination information' do
      WebMock.stub_request(:get, %r{http://example.com/.*})

      with_agent do
        ElasticAPM.with_transaction 'Http.rb test' do
          HTTP.get('http://example.com/page.html')
        end
      end

      span, = @intercepted.spans

      destination = span.context.destination
      expect(destination.name).to match('http://example.com')
      expect(destination.resource).to match('example.com:80')
      expect(destination.type).to match('external')
      expect(destination.address).to match('example.com')
      expect(destination.port).to match(80)
    end

    it 'adds destination information with IPv6' do
      WebMock.stub_request(:get, %r{http://\[::1\]:8080/.*})

      with_agent do
        ElasticAPM.with_transaction 'Http.rb test IPv6' do
          HTTP.get('http://[::1]:8080/page.html')
        end
      end

      span, = @intercepted.spans

      destination = span.context.destination
      expect(destination.name).to match('http://[::1]:8080')
      expect(destination.resource).to match('[::1]:8080')
      expect(destination.type).to match('external')
      expect(destination.address).to match('::1')
      expect(destination.port).to match(8080)
    end

    it 'adds traceparent header' do
      req_stub =
        WebMock.stub_request(:get, %r{http://example.com/.*}).with do |req|
          header = req.headers['Traceparent']
          expect(header).to_not be nil
          expect { TraceContext::Traceparent.parse(header) }.to_not raise_error
        end

      with_agent do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      expect(req_stub).to have_been_requested
    end

    it 'adds traceparent header with no span' do
      req_stub = WebMock.stub_request(:get, %r{http://example.com/.*})

      with_agent transaction_max_spans: 0 do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      expect(req_stub).to have_been_requested
    end

    it 'adds failure outcome to a span' do
      WebMock.stub_request(:get, 'http://example.com')
             .to_return(status: [400, 'Bad Request'])

      with_agent do
        ElasticAPM.with_transaction 'HTTP test' do
          HTTP.get('http://example.com')
        end
      end

      span, = @intercepted.spans

      expect(span).to_not be nil
      expect(span.outcome).to eq 'failure'
    end
  end
end
