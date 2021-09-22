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
  module Transport
    module Serializers
      RSpec.describe MetadataSerializer do
        let(:config) { Config.new }

        subject { described_class.new config }
        let(:result) { subject.build(metadata) }

        describe '#build' do
          let(:metadata) { Metadata.new config }

          it 'is a bunch of hashes and no labels' do
            expect(result[:metadata]).to be_a Hash
            expect(result[:metadata][:service]).to be_a Hash
            expect(result[:metadata][:process]).to be_a Hash
            expect(result[:metadata][:system]).to be_a Hash
            expect(result[:metadata][:labels]).to be_nil
          end

          context 'with a node name' do
            let(:config) { Config.new(service_node_name: 'a') }

            it 'has a node obj' do
              expect(result.dig(:metadata, :service, :node, :configured_name)).to eq 'a'
            end
          end

          context 'when there are global_labels' do
            let(:metadata) do
              Metadata.new Config.new(global_labels: { apples: 'oranges' })
            end

            it 'is a bunch of hashes' do
              expect(result[:metadata]).to be_a Hash
              expect(result[:metadata][:service]).to be_a Hash
              expect(result[:metadata][:process]).to be_a Hash
              expect(result[:metadata][:system]).to be_a Hash
              expect(result[:metadata][:labels]).to be_a Hash
              expect(result[:metadata][:cloud]).to be nil
            end
          end

          context "with cloud info" do
            it 'adds cloud info' do
              metadata.cloud.provider = 'something'
              metadata.cloud.account_id = 'asdf'

              expect(result.dig(:metadata, :cloud)).to match(
                account: { id: 'asdf' },
                provider: 'something'
              )
            end
          end

          context "with kubernetes info" do
            let(:metadata) do
              with_env(
                'KUBERNETES_NAMESPACE' => 'my-namespace',
                'KUBERNETES_NODE_NAME' => 'my-node-name',
                'KUBERNETES_POD_NAME' => 'my-pod-name',
                'KUBERNETES_POD_UID' => 'my-pod-uid'
              ) do
                Metadata.new(Config.new(cloud_provider: 'none'))
              end
            end

            it 'formats correctly' do
              expect(result.dig(:metadata, :system, :kubernetes)).to match(
                namespace: "my-namespace",
                node: { name: "my-node-name" },
                pod: { name: "my-pod-name", uid: "my-pod-uid" }
              )
            end
          end

          context "with container info" do
            let(:metadata) do
              Metadata.new(Config.new)
            end

            it 'adds container info' do
              container_id = "container-id"
              allow(metadata.system).to receive(:container).and_return(id: container_id)

              expect(result.dig(:metadata, :system, :container)).to match(
                id: container_id
              )
            end
          end
        end
      end
    end
  end
end
