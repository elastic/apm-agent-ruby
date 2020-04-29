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

if defined?(Grape)
  enabled = true
else
  puts '[INFO] Skipping Grape spec'
end

if enabled
  RSpec.describe 'Grape integration', :mock_intake, :allow_running_agent do
    include Rack::Test::Methods

    def app
      @app ||= GrapeTestApp
    end

    before :all do
      class GrapeTestApp < ::Grape::API
        use ElasticAPM::Middleware

        get :pingpong do
          { message: 'Hello' }
        end

        resource :statuses do
          desc 'Return a status.'
          params do
            requires :id, type: Integer, desc: 'Status id.'
          end
          route_param :id do
            get do
              { status: params[:id] }
            end
          end
        end
      end

      MockIntake.instance.stub!

      ElasticAPM::Grape.start(
        GrapeTestApp,
        api_request_time: '100ms',
        span_frames_min_duration: -1
      )
    end

    after :all do
      ElasticAPM.stop
    end

    it 'sets the framework metadata' do
      get '/pingpong'

      wait_for transactions: 1, spans: 1

      service = @mock_intake.metadatas.first['service']
      expect(service['name']).to eq 'GrapeTestApp'
      expect(service['framework']['name']).to eq 'Grape'
      expect(service['framework']['version'])
        .to match(/\d+\.\d+\.\d+(\.\d+)?/)
    end

    context 'endpoint_run.grape' do
      it 'sets the transaction and span values' do
        get '/pingpong'
        wait_for transactions: 1, spans: 1

        span = @mock_intake.spans.last
        expect(span['name']).to eq('GET /pingpong')
        expect(span['type']).to eq('app.resource')

        transaction = @mock_intake.transactions.last
        expect(transaction['name']).to eq('GET /pingpong')
      end

      it 'sets the backtrace' do
        get '/pingpong'
        wait_for transactions: 1, spans: 1

        span = @mock_intake.spans.last
        expect(span['stacktrace'][0]).not_to be(nil)
        expect(span['stacktrace'][0]['filename'])
          .to eq('integration/grape_spec.rb')
      end

      context 'params specified' do
        it 'sets the transaction and span values' do
          get '/statuses/1'
          wait_for transactions: 1, spans: 1

          span = @mock_intake.spans.last
          expect(span['name']).to eq('GET /statuses/:id')
          expect(span['type']).to eq('app.resource')

          transaction = @mock_intake.transactions.last
          expect(transaction['name']).to eq('GET /statuses/:id')
        end
      end
    end
  end
end
