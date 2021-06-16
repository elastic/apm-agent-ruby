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
      ::Aws::SQS::Client.new(region: 'us-west-2', stub_responses: true)
    end

    context 'SQS send_message' do
      it 'spans operations', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.send_message(
              queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
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

        # Span context
        expect(span.context.destination.service.resource).to eq('sqs/my-queue')
        expect(span.context.destination.cloud.region).to eq('us-east-1')
        expect(span.context.message.queue_name).to eq('my-queue')
      end

      it 'adds trace context to the message attributes', :intercept do
        allow(client).to receive(:build_request).and_call_original

        with_agent do
          ElasticAPM.with_transaction do
            client.send_message(
                queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
                message_body: 'some message'
            )
          end
        end

        expect(client).to have_received(:build_request) do |key, params|
          expect(params[:message_attributes]).to include(
            "Traceparent" => hash_including(data_type: "String")
          )
          expect(params[:message_attributes]).to include(
            "Elastic-Apm-Traceparent" => hash_including(data_type: "String")
          )
          expect(params[:message_attributes]).to include(
            "Tracestate" => hash_including(data_type: "String")
          )
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

    context 'SQS send_message_batch' do
      it 'spans operations', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.send_message_batch(
              queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
              entries: [
                {
                  id: 'some_id',
                  message_body: 'some message'
                }
              ]
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS SEND_BATCH to my-queue')
        expect(span.type).to eq('messaging')
        expect(span.subtype).to eq('sqs')
        expect(span.action).to eq('send_batch')
        expect(span.outcome).to eq('success')

        # Span context
        expect(span.context.destination.service.resource).to eq('sqs/my-queue')
        expect(span.context.message.queue_name).to eq('my-queue')
      end

      it 'adds trace context to the message attributes', :intercept do
        allow(client).to receive(:build_request).and_call_original

        with_agent do
          ElasticAPM.with_transaction do
            client.send_message_batch(
              queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
              entries: [
                {
                  id: 'some_id',
                  message_body: 'some message'
                },
                {
                  id: 'some_id_2',
                  message_body: 'some message_2'
                }
              ]
            )
          end
        end

        expect(client).to have_received(:build_request) do |_key, params|
          params[:entries].each do |entry|
            expect(entry[:message_attributes]).to include(
              "Traceparent" => hash_including(data_type: "String")
            )
            expect(entry[:message_attributes]).to include(
              "Elastic-Apm-Traceparent" => hash_including(data_type: "String")
            )
            expect(entry[:message_attributes]).to include(
              "Tracestate" => hash_including(data_type: "String")
            )
          end
        end
      end

      context 'when the operation fails' do
        it 'sets span outcome to `failure`', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              begin
                client.send_message_batch(
                  queue_url: '',
                  entries: [
                    {
                      id: 'some_id',
                      message_body: 'some message'
                    }
                  ]
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

    context 'SQS receive_message' do
      it "spans operations", :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.receive_message(
              queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS RECEIVE from my-queue')
        expect(span.type).to eq('messaging')
        expect(span.subtype).to eq('sqs')
        expect(span.action).to eq('receive')
        expect(span.outcome).to eq('success')

        # Span context
        expect(span.context.destination.service.resource).to eq('sqs/my-queue')
        expect(span.context.message.queue_name).to eq('my-queue')
      end

      context 'when the operation fails' do
        it 'sets span outcome to `failure`', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              begin
                client.receive_message(
                  queue_url: ''
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

    context 'SQS delete_message' do
      it "spans operations", :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.delete_message(
              queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
              receipt_handle: 'aaaa'
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS DELETE from my-queue')
        expect(span.action).to eq('delete')
        expect(span.outcome).to eq('success')
      end

      context 'when the operation fails' do
        it 'sets span outcome to `failure`', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              begin
                client.delete_message(
                  queue_url: '',
                  receipt_handle: 'aaaa'
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

    context 'SQS delete_message_batch' do
      it "spans operations", :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.delete_message_batch(
              queue_url: 'https://sqs.us-east-1.amazonaws.com/1234567890/my-queue',
              entries: [
                {
                  id: 'some_id',
                  receipt_handle: 'aaaa'
                }
              ]
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SQS DELETE_BATCH from my-queue')
      end

      context 'when the operation fails' do
        it 'sets span outcome to `failure`', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              begin
                client.delete_message_batch(
                  queue_url: '',
                  entries: [
                    {
                      id: 'some_id',
                      receipt_handle: 'aaaa'
                    }
                  ]
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
end
