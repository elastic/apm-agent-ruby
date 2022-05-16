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
require 'aws-sdk-sns'

module ElasticAPM
  RSpec.describe 'Spy: SNS' do
    let(:client) do
      ::Aws::SNS::Client.new(region: 'us-west-2', stub_responses: true)
    end

    context 'SNS publish' do
      it 'spans operations', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            client.publish(
              topic_arn: 'arn:aws:sns:us-east-1:123456789012:MyTopic',
              message: 'some message'
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('SNS PUBLISH to MyTopic')
        expect(span.type).to eq('messaging')
        expect(span.subtype).to eq('sns')
        expect(span.action).to eq('publish')
        expect(span.outcome).to eq('success')

        # Span context
        expect(span.context.destination.service.resource).to eq('sns/MyTopic')
        expect(span.context.destination.cloud.region).to eq('us-east-1')
        expect(span.context.message.queue_name).to eq('MyTopic')
      end

      context 'when a topic arn is provided' do
        it 'extracts the topic and region from an arn in path style', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              client.publish(
                topic_arn: 'arn:aws:sns:us-east-1:123456789012:MyTopic/my-sub-topic',
                message: 'some message'
              )
            end
          end

          span = @intercepted.spans.first

          expect(span.name).to eq('SNS PUBLISH to my-sub-topic')
          expect(span.context.destination.service.resource).to eq('sns/my-sub-topic')
          expect(span.context.message.queue_name).to eq('my-sub-topic')
        end

        it 'extracts the topic and region from an arn in colon style', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              client.publish(
                topic_arn: 'arn:aws:sns:us-east-1:123456789012:MyTopic',
                message: 'some message'
              )
            end
          end

          span = @intercepted.spans.first

          expect(span.name).to eq('SNS PUBLISH to MyTopic')
          expect(span.context.destination.service.resource).to eq('sns/MyTopic')
          expect(span.context.message.queue_name).to eq('MyTopic')
        end
      end

      context 'when a phone number is provided' do
        it 'handles a target phone number', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              client.publish(
                phone_number: '+1XXX5550100',
                message: 'some message'
              )
            end
          end

          span = @intercepted.spans.first

          expect(span.name).to eq('SNS PUBLISH to [PHONENUMBER]')
          expect(span.context.destination.service.resource).to eq('sns/[PHONENUMBER]')
          expect(span.context.message.queue_name).to eq('[PHONENUMBER]')
        end
      end

      context 'when a target arn is provided' do
        context 'when the target arn is an accesspoint' do
          it 'handles a target arn access point in path style', :intercept do
            with_agent do
              ElasticAPM.with_transaction do
                client.publish(
                  target_arn: 'arn:aws:s3:us-east-1:123456789012:accesspoint/myendpoint',
                  message: 'some message'
                )
              end
            end

            span = @intercepted.spans.first

            expect(span.name).to eq('SNS PUBLISH to accesspoint/myendpoint')
            expect(span.context.destination.service.resource).to eq('sns/accesspoint/myendpoint')
            expect(span.context.message.queue_name).to eq('accesspoint/myendpoint')
          end

          it 'handles a target arn access point in colon style', :intercept do
            with_agent do
              ElasticAPM.with_transaction do
                client.publish(
                  target_arn: 'arn:aws:s3:us-east-1:123456789012:accesspoint:myendpoint',
                  message: 'some message'
                )
              end
            end

            span = @intercepted.spans.first

            expect(span.name).to eq('SNS PUBLISH to accesspoint:myendpoint')
            expect(span.context.destination.service.resource).to eq('sns/accesspoint:myendpoint')
            expect(span.context.message.queue_name).to eq('accesspoint:myendpoint')
          end
        end

        it 'handles a target arn in path style', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              client.publish(
                target_arn: 'arn:aws:s3:us-east-1:123456789012:MyTopic/my-sub-topic',
                message: 'some message'
              )
            end
          end

          span = @intercepted.spans.first

          expect(span.name).to eq('SNS PUBLISH to my-sub-topic')
          expect(span.context.destination.service.resource).to eq('sns/my-sub-topic')
          expect(span.context.message.queue_name).to eq('my-sub-topic')
        end

        it 'handles a target arn in colon style', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              client.publish(
                target_arn: 'arn:aws:s3:us-east-1:123456789012:MyTopic',
                message: 'some message'
              )
            end
          end

          span = @intercepted.spans.first

          expect(span.name).to eq('SNS PUBLISH to MyTopic')
          expect(span.context.destination.service.resource).to eq('sns/MyTopic')
          expect(span.context.message.queue_name).to eq('MyTopic')
        end
      end

      it 'adds trace context to the message attributes', :intercept do
        allow(client).to receive(:build_request).and_call_original

        with_agent do
          ElasticAPM.with_transaction do
            client.publish(
              target_arn: 'arn:aws:s3:us-east-1:123456789012:MyTopic',
              message: 'some message'
            )
          end
        end

        expect(client).to have_received(:build_request) do |_, args|
          expect(args[:message_attributes]).to include(
            "Traceparent" => hash_including(data_type: "String")
          )
          expect(args[:message_attributes]).to include(
            "Elastic-Apm-Traceparent" => hash_including(data_type: "String")
           )
          expect(args[:message_attributes]).to include(
            "Tracestate" => hash_including(data_type: "String")
          )
        end
      end

      context 'when the operation fails' do
        it 'sets span outcome to `failure`', :intercept do
          with_agent do
            ElasticAPM.with_transaction do
              begin
                client.publish(
                  target_arn: 'arn:aws:s3:us-east-1:123456789012:MyTopic',
                  message: 1
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
