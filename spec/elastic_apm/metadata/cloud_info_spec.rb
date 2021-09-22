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

      AZURE_EXAMPLE = <<-JSON
        {
          "location": "westus2",
          "name": "basepi-test",
          "resourceGroupName": "basepi-testing",
          "subscriptionId": "7657426d-c4c3-44ac-88a2-3b2cd59e6dba",
          "vmId": "e11ebedc-019d-427f-84dd-56cd4388d3a8",
          "vmScaleSetName": "",
          "vmSize": "Standard_D2s_v3",
          "zone": ""
        }
      JSON
    end

    describe '#fetch!' do
      let(:config) { Config.new }
      subject { described_class.new(config) }

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
          # rubocop:disable Style/NumericLiterals
          expect(subject.instance_id).to eq(4306570268266786072)
          expect(subject.instance_name).to eq("basepi-test")
          expect(subject.project_id).to eq(513326162531)
          # rubocop:enable Style/NumericLiterals
          expect(subject.instance_name).to eq('basepi-test')
          expect(subject.project_name).to eq('elastic-apm')
          expect(subject.availability_zone).to eq('us-west3-a')
          expect(subject.region).to eq('us-west3')
          expect(subject.machine_type).to eq('projects/513326162531/machineTypes/n1-standard-1')

          expect(@gcp_mock).to have_been_requested
        end
      end

      context 'azure' do
        let(:config) { Config.new(cloud_provider: 'azure') }

        before do
          @azure_mock =
            WebMock.stub_request(:get, Metadata::CloudInfo::AZURE_URI)
                   .to_return(body: CloudExamples::AZURE_EXAMPLE)
        end

        it 'fetches metadata from azure' do
          subject.fetch!

          expect(subject.provider).to eq "azure"
          expect(subject.account_id).to eq "7657426d-c4c3-44ac-88a2-3b2cd59e6dba"
          expect(subject.instance_id).to eq "e11ebedc-019d-427f-84dd-56cd4388d3a8"
          expect(subject.instance_name).to eq "basepi-test"
          expect(subject.project_name).to eq "basepi-testing"
          expect(subject.machine_type).to eq "Standard_D2s_v3"
          expect(subject.region).to eq "westus2"

          expect(@azure_mock).to have_been_requested
        end
      end

      context 'azure app services' do
        let(:config) { Config.new(cloud_provider: 'azure') }

        before do
          WebMock.stub_request(
            :get,
            Metadata::CloudInfo::AZURE_URI
          ).to_raise(HTTP::ConnectionError)
        end

        it 'reads metadata from ENV' do
          with_env(
            'WEBSITE_OWNER_NAME' => 'f5940f10-2e30-3e4d-a259-63451ba6dae4+elastic-apm-AustraliaEastwebspace',
            'WEBSITE_INSTANCE_ID' => '__instance_id',
            'WEBSITE_SITE_NAME' => '__site_name',
            'WEBSITE_RESOURCE_GROUP' => '__resource_group'
          ) do
            subject.fetch!
          end

          expect(subject.provider).to eq "azure"
          expect(subject.account_id).to eq "f5940f10-2e30-3e4d-a259-63451ba6dae4"
          expect(subject.instance_id).to eq "__instance_id"
          expect(subject.instance_name).to eq "__site_name"
          expect(subject.project_name).to eq "__resource_group"
          expect(subject.region).to eq "AustraliaEast"
        end
      end

      context 'auto' do
        let(:config) { Config.new(cloud_provider: 'auto') }

        context 'timeouts' do
          it 'tries all three' do
            WebMock.stub_request(
              :get,
              Metadata::CloudInfo::AWS_URI
            ).to_timeout
            WebMock.stub_request(
              :get,
              Metadata::CloudInfo::GCP_URI
            ).to_timeout
            WebMock.stub_request(
              :get,
              Metadata::CloudInfo::AZURE_URI
            ).to_timeout

            subject.fetch!
            expect(subject.provider).to be nil
          end
        end

        context 'connection errors' do
          it 'tries all three' do
            WebMock.stub_request(
              :get,
              Metadata::CloudInfo::AWS_URI
            ).to_raise(HTTP::ConnectionError)
            WebMock.stub_request(
              :get,
              Metadata::CloudInfo::GCP_URI
            ).to_raise(HTTP::ConnectionError)
            WebMock.stub_request(
              :get,
              Metadata::CloudInfo::AZURE_URI
            ).to_raise(HTTP::ConnectionError)

            subject.fetch!
            expect(subject.provider).to be nil
          end
        end
      end

      context 'none' do
        let(:config) { Config.new(cloud_provider: 'none') }

        it 'tries none' do
          subject.fetch!
          expect(subject.provider).to be nil
        end
      end
    end
  end
end
