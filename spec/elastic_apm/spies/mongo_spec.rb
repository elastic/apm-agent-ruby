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

require 'mongo'

module ElasticAPM
  RSpec.describe 'Spy: MongoDB' do
    context 'db admin commands' do
      let(:event) do
        double('event',
          command: { 'listCollections' => 1 },
          command_name: 'listCollections',
          database_name: 'elastic-apm-test',
          operation_id: 123)
      end
      let(:subscriber) { Spies::MongoSpy::Subscriber.new }

      it 'captures command properties', :intercept do
        span = with_agent do
          ElasticAPM.with_transaction do
            subscriber.started(event)
            subscriber.succeeded(event)
          end
        end

        expect(span.name).to eq 'elastic-apm-test.listCollections'
        expect(span.type).to eq 'db'
        expect(span.subtype).to eq 'mongodb'
        expect(span.action).to eq 'query'
        expect(span.duration).to_not be_nil
        expect(span.outcome).to eq 'success'

        db = span.context.db
        expect(db.instance).to eq 'elastic-apm-test'
        expect(db.type).to eq 'mongodb'
        expect(db.statement).to eq('{"listCollections"=>1}')
                            .or eq("{\"listCollections\" => 1}")
        expect(db.user).to be nil

        destination = span.context.destination
        expect(destination.service.name).to eq 'mongodb'
        expect(destination.service.resource).to eq 'mongodb'
        expect(destination.service.type).to eq 'db'
      end

      it 'sets outcome to `failure` for a failed operation', :intercept do
        span = with_agent do
          ElasticAPM.with_transaction do
            subscriber.started(event)
            subscriber.failed(event)
          end
        end

        expect(span.outcome).to eq 'failure'
      end
    end

    context 'collection commands', :intercept do
      let(:event) do
        double('event',
          command: { 'find' => 'testing',
                     'filter' => { 'a' => 'bc' } },
          command_name: 'find',
          database_name: 'elastic-apm-test',
          operation_id: 456)
      end
      let(:subscriber) { Spies::MongoSpy::Subscriber.new }

      it 'captures command properties' do
        span = with_agent do
          ElasticAPM.with_transaction do
            subscriber.started(event)
            subscriber.succeeded(event)
          end
        end

        expect(span.name).to eq 'elastic-apm-test.testing.find'
        expect(span.type).to eq 'db'
        expect(span.subtype).to eq 'mongodb'
        expect(span.action).to eq 'query'
        expect(span.duration).to_not be_nil
        expect(span.outcome).to eq 'success'

        db = span.context.db
        expect(db.instance).to eq 'elastic-apm-test'
        expect(db.type).to eq 'mongodb'
        expect(db.statement).to eq('{"find"=>"testing", "filter"=>{"a"=>"bc"}}')
                            .or eq("{\"find\" => \"testing\", \"filter\" => {\"a\" => \"bc\"}}")
        expect(db.user).to be nil
      end
    end

    context 'requests in different threads', :intercept do
      let(:subscriber) { Spies::MongoSpy::Subscriber.new }

      it 'captures all operations' do
        thread_count = 50

        with_agent do
          Array.new(thread_count).map do
            Thread.new do |t|
              event = double('event',
                     command: { 'find' => 'testing',
                                'filter' => { 'a' => 'bc' } },
                     command_name: 'find',
                     database_name: 'elastic-apm-test',
                     operation_id: rand(thread_count+1))

              ElasticAPM.with_transaction do
                subscriber.started(event)
                subscriber.succeeded(event)
              end
            end
          end.map(&:join)
        end

        expect(@intercepted.spans.length).to be(thread_count)
      end
    end
  end
end
