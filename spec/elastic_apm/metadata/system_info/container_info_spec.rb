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
  class Metadata
    RSpec.describe SystemInfo::ContainerInfo do
      context 'containers' do
        context 'with env' do
          it 'reads variables from env' do
            with_env(
              'KUBERNETES_NAMESPACE' => 'my-namespace',
              'KUBERNETES_NODE_NAME' => 'my-node-name',
              'KUBERNETES_POD_NAME' => 'my-pod-name',
              'KUBERNETES_POD_UID' => 'my-pod-uid'
            ) do
              subject.read!

              expect(subject.kubernetes_namespace).to eq('my-namespace')
              expect(subject.kubernetes_node_name).to eq('my-node-name')
              expect(subject.kubernetes_pod_name).to eq('my-pod-name')
              expect(subject.kubernetes_pod_uid).to eq('my-pod-uid')
            end
          end
        end

        context 'with cgroup' do
          let(:tempfile) { Tempfile.new }

          before do
            tempfile.write(lines)
            tempfile.rewind
            tempfile.close
          end

          after { tempfile.unlink }

          subject do
            described_class.new(cgroup_path: tempfile.path).read!
          end

          # rubocop:disable Metrics/LineLength
          context '12:devices:...' do
            let(:lines) do
              '12:devices:/docker/051e2ee0bce99116029a13df4a9e943137f19f957f38ac02d6bad96f9b700f76'
            end
            its(:container_id) do
              should eq '051e2ee0bce99116029a13df4a9e943137f19f957f38ac02d6bad96f9b700f76'
            end
          end

          context '1:name=systemd:/system.slice/...' do
            let(:lines) do
              '1:name=systemd:/system.slice/docker-cde7c2bab394630a42d73dc610b9c57415dced996106665d427f6d0566594411.scope'
            end
            its(:container_id) do
              should eq 'cde7c2bab394630a42d73dc610b9c57415dced996106665d427f6d0566594411'
            end
          end

          context '1:name:systemd:/kubepods/...' do
            let(:lines) do
              '1:name=systemd:/kubepods/besteffort/pode9b90526-f47d-11e8-b2a5-080027b9f4fb/15aa6e53-b09a-40c7-8558-c6c31e36c88a'
            end
            its(:container_id) do
              should eq '15aa6e53-b09a-40c7-8558-c6c31e36c88a'
            end
            its(:kubernetes_pod_uid) do
              should eq 'e9b90526-f47d-11e8-b2a5-080027b9f4fb'
            end
          end

          context '1:name=systemd:/kubepods.slice/...' do
            let(:lines) do
              '1:name=systemd:/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod90d81341_92de_11e7_8cf2_507b9d4141fa.slice/crio-2227daf62df6694645fee5df53c1f91271546a9560e8600a525690ae252b7f63.scope'
            end
            its(:container_id) do
              should eq '2227daf62df6694645fee5df53c1f91271546a9560e8600a525690ae252b7f63'
            end
            its(:kubernetes_pod_uid) do
              should eq '90d81341_92de_11e7_8cf2_507b9d4141fa'
            end
          end
          # rubocop:enable Metrics/LineLength
        end
      end
    end
  end
end
