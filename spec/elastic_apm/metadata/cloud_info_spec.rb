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

module ElasticAPM
  RSpec.describe Metadata::CloudInfo do
    module CloudExamples
      AWS_EXAMPLE = <<-JSON
        {
            "devpayProductCodes" : null,
            "marketplaceProductCodes" : [ "1abc2defghijklm3nopqrs4tu" ], 
            "availabilityZone" : "us-west-2b",
            "privateIp" : "10.158.112.84",
            "version" : "2017-09-30",
            "instanceId" : "i-1234567890abcdef0",
            "billingProducts" : null,
            "instanceType" : "t2.micro",
            "accountId" : "123456789012",
            "imageId" : "ami-5fb8c835",
            "pendingTime" : "2016-11-19T16:32:11Z",
            "architecture" : "x86_64",
            "kernelId" : null,
            "ramdiskId" : null,
            "region" : "us-west-2"
        }
      JSON

      GCP_EXAMPLE = <<-JSON
        {
          "instance": {
              "id": 4306570268266786072,
              "machineType": "projects/513326162531/machineTypes/n1-standard-1",
              "name": "basepi-test",
              "zone": "projects/513326162531/zones/us-west3-a"
          },
          "project": {"numericProjectId": 513326162531, "projectId": "elastic-apm"}
        }
      JSON
    end

    describe '#fetch!' do
      let(:config) { Config.new }
      subject { described_class.new(config) }

      after { WebMock.reset! }

      context 'aws' do
        let(:config) { Config.new(cloud_provider: 'aws') }

        before do
          @aws_mock =
            WebMock.stub_request(:get, Metadata::CloudInfo::AWS_URI)
            .to_return(body: CloudExamples::AWS_EXAMPLE)
        end

        it 'fetches metadata from aws' do
          subject.fetch!

          expect(subject.account_id).to eq '123456789012'
          expect(subject.instance_id).to eq 'i-1234567890abcdef0'
          expect(subject.availability_zone).to eq 'us-west-2b'
          expect(subject.provider).to eq 'aws'
          expect(subject.region).to eq 'us-west-2'

          expect(@aws_mock).to have_been_requested
        end
      end

      context 'gcp' do
        let(:config) { Config.new(cloud_provider: 'gcp') }

        before do
          @gcp_mock =
            WebMock.stub_request(:get, Metadata::CloudInfo::GCP_URI)
            .to_return(body: CloudExamples::GCP_EXAMPLE)
        end

        it 'fetches metadata from gcp' do
          subject.fetch!

          expect(subject.provider).to eq('gcp')
          expect(subject.instance_id).to eq(4306570268266786072)
          expect(subject.instance_name).to eq("basepi-test")
          expect(subject.project_id).to eq(513326162531)
          expect(subject.project_name).to eq("elastic-apm")
          expect(subject.availability_zone).to eq('us-west3-a')
          expect(subject.region).to eq('us-west3')
          expect(subject.machine_type).to eq('projects/513326162531/machineTypes/n1-standard-1')

          expect(@gcp_mock).to have_been_requested
        end
      end
    end
  end
end
