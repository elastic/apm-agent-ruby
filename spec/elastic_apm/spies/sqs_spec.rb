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
require 'aws-sdk-sqs'

module ElasticAPM
  RSpec.describe 'Spy: SQS' do
    let(:client) do
      ::Aws::SQS::Client.new(stub_responses: true)
    end

    context 'SQS send_message' do
      it 'spans operations', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.send_message(
              queue_url: 'https://sqs.us-west-2.amazonaws.com/1234567890/my-queue',
              message_body: 'some message'
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS SEND to my-queue')
        expect(span.type).to eq('messaging')
        expect(span.subtype).to eq('sqs')
        expect(span.action).to eq('send')
        expect(span.outcome).to eq('success')
      end

      it 'add trace context to the message attributes', :intercept do
        with_agent do
          expect(client).to receive(:send_message_without_apm).with()
          ElasticAPM.with_transaction do
            client.send_message(
              queue_url: 'https://sqs.us-west-2.amazonaws.com/1234567890/my-queue',
              message_body: 'some message'
            )
          end
        end
      end
    end

    context 'SQS send_message_batch' do
      it 'spans operations', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.send_message_batch(
              queue_url: 'https://sqs.us-west-2.amazonaws.com/1234567890/my-queue',
              entries: [
                  {
                    id: 1,
                    message_body: 'some message'
                  }
              ]
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS SEND BATCH to my-queue')
        expect(span.type).to eq('messaging')
        expect(span.subtype).to eq('sqs')
        expect(span.action).to eq('send')
        expect(span.outcome).to eq('success')
      end
    end

    context 'SQS receive_message' do
      it "spans operations", :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.receive_message(
              queue_url: 'https://sqs.us-west-2.amazonaws.com/1234567890/my-queue',
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS RECEIVE from my-queue')
        expect(span.type).to eq('messaging')
        expect(span.subtype).to eq('sqs')
        expect(span.action).to eq('receive')
        expect(span.outcome).to eq('success')
      end
    end

    context 'when the operation fails' do
      it 'sets span outcome to `failure`', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            begin
              client.send_message(
                queue_url: '',
                message_body: 'some message'
              )
            rescue
            end
          end
          span = @intercepted.spans.first
          expect(span.outcome).to eq('failure')
        end
      end
    end
  end
end
