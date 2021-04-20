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
require 'aws-sdk-s3'

module ElasticAPM
  RSpec.describe 'Spy: S3' do
    let(:s3_client) do
      ::Aws::S3::Client.new(stub_responses: true, region: 'us-west-1')
    end

    it "spans operations", :intercept do
      with_agent do
        ElasticAPM.with_transaction do
          s3_client.create_bucket(bucket: 'my-bucket')
        end
      end

      span = @intercepted.spans.first

      expect(span.name).to eq('S3 CreateBucket my-bucket')
      expect(span.type).to eq('storage')
      expect(span.subtype).to eq('s3')
      expect(span.action).to eq('CreateBucket')
      expect(span.outcome).to eq('success')

      # span context destination
      expect(span.context.destination.service.resource).to eq('my-bucket')
      expect(span.context.destination.service.type).to eq('storage')
      expect(span.context.destination.service.name).to eq('s3')
      expect(span.context.destination.cloud.region).to eq('us-west-1')
    end

    context 'when bucket name is a symbol' do
      it 'sets bucket name', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            s3_client.create_bucket(bucket: :mybucket)
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('S3 CreateBucket mybucket')
        expect(span.context.destination.service.resource).to eq('mybucket')
      end
    end

    context 'when there is no bucket name' do
      it 'does not include a bucket in the span name and no service on destination', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            s3_client.list_buckets
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('S3 ListBuckets')
        expect(span.action).to eq('ListBuckets')
        expect(span.context.destination.service).to eq(nil)
      end
    end

    context 'when an Access Point is provided' do
      it 'extracts the access point name from the access point', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            s3_client.get_object(
              bucket: 'arn:aws:s3:us-west-1:123456789012:accesspoint/myendpoint',
              key: 'test'
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('S3 GetObject accesspoint/myendpoint')
        expect(span.context.destination.service.resource).to eq('accesspoint/myendpoint')
      end

      it 'extracts the region from the access point with a slash', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            s3_client.get_object(
              bucket: 'arn:aws:s3:us-east-2:123456789012:accesspoint/myendpoint',
              key: 'test'
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('S3 GetObject accesspoint/myendpoint')
        expect(span.action).to eq('GetObject')

        # span context destination
        expect(span.context.destination.cloud.region).to eq('us-east-2')
        expect(span.context.destination.service.resource).to eq('accesspoint/myendpoint')
      end

      it 'extracts the region from the access point with a colon', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            s3_client.get_object(
              bucket: 'arn:aws:s3:us-east-2:123456789012:accesspoint:myendpoint',
              key: 'test'
            )
          end
        end

        span = @intercepted.spans.first

        expect(span.name).to eq('S3 GetObject accesspoint:myendpoint')
        expect(span.context.destination.service.resource).to eq('accesspoint:myendpoint')
        expect(span.context.destination.cloud.region).to eq('us-east-2')
      end
    end

    it "caches the formatted operation name", :intercept do
      with_agent do
        expect(
          ElasticAPM::Spies::S3Spy::MUTEX
        ).to receive(:synchronize).once.and_call_original

        ElasticAPM.with_transaction do
          s3_client.list_buckets
          s3_client.list_buckets
        end
      end

      span1, span2 = @intercepted.spans
      expect(span1.name).to eq('S3 ListBuckets')
      expect(span2.name).to eq('S3 ListBuckets')
    end

    context 'when the operation fails' do
      it 'sets span outcome to `failure`', :intercept do
        with_agent do
          ElasticAPM.with_transaction do
            begin
              s3_client.get_object(
                bucket: 'arn:aws:s3:::mybucket',
                key: 'test'
              )
            rescue
            end
          end
        end

        span = @intercepted.spans.first

        expect(span.outcome).to eq('failure')
      end
    end
  end
end
