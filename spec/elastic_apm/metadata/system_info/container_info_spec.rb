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
            lines.each { |l| tempfile.write(l) }
            tempfile.rewind
            tempfile.close
          end

          after { tempfile.unlink }

          subject do
            described_class.new(cgroup_path: tempfile.path).read!
          end

          # container_id, kubernetes_pod_uid, *lines
          [[
            '051e2ee0bce99116029a13df4a9e943137f19f957f38ac02d6bad96f9b700f76',
            nil,
            '12:devices:/docker/051e2ee0bce99116029a13df4a9e943137f19f957f38a'\
            'c02d6bad96f9b700f76'
          ], [
            'cde7c2bab394630a42d73dc610b9c57415dced996106665d427f6d0566594411',
            nil,
            '1:name=systemd:/system.slice/docker-cde7c2bab394630a42d73dc610b9'\
            'c57415dced996106665d427f6d0566594411.scope'
          ], [
            '15aa6e53-b09a-40c7-8558-c6c31e36c88a',
            'e9b90526-f47d-11e8-b2a5-080027b9f4fb',
            '1:name=systemd:/kubepods/besteffort/pode9b90526-f47d-11e8-b2a5-0'\
            '80027b9f4fb/15aa6e53-b09a-40c7-8558-c6c31e36c88a'
          ], [
            '244a65edefdffe31685c42317c9054e71dc1193048cf9459e2a4dd35cbc1dba4',
            '0e886e9a-3879-45f9-b44d-86ef9df03224',
            '12:pids:/kubepods/kubepods/besteffort/pod0e886e9a-3879-45f9-b44d-'\
            '86ef9df03224/244a65edefdffe31685c42317c9054e71dc1193048cf9459e2a'\
            '4dd35cbc1dba4'
          ], [
            '7fe41c8a2d1da09420117894f11dd91f6c3a44dfeb7d125dc594bd53468861df',
            '5eadac96-ab58-11ea-b82b-0242ac110009',
            '10:cpuset:/kubepods/pod5eadac96-ab58-11ea-b82b-0242ac110009/7fe4'\
            '1c8a2d1da09420117894f11dd91f6c3a44dfeb7d125dc594bd53468861df'
          ], [
            "b15a5bdedd2e7645c3be271364324321b908314e4c77857bbfd32a041148c07f",
             "22949dce-fd8b-11ea-8ede-98f2b32c645c",
             "9:freezer:/kubepods.slice/kubepods-pod22949dce_fd8b_11ea_8ede_" \
             "98f2b32c645c.slice/docker-b15a5bdedd2e7645c3be271364324321b908" \
             "314e4c77857bbfd32a041148c07f.scope"
          ]].each do |(c_id, kp_id, *lines)|
            context lines[0] do
              let(:lines) { lines }
              its(:container_id) { is_expected.to eq c_id }
              its(:kubernetes_pod_uid) { is_expected.to eq kp_id }
            end
          end
        end
      end
    end
  end
end
