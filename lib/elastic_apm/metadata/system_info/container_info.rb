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

module ElasticAPM
  class Metadata
    class SystemInfo
      # @api private
      class ContainerInfo
        CGROUP_PATH = '/proc/self/cgroup'

        attr_accessor :container_id, :kubernetes_namespace,
          :kubernetes_node_name, :kubernetes_pod_name, :kubernetes_pod_uid

        def initialize(cgroup_path: CGROUP_PATH)
          @cgroup_path = cgroup_path
        end

        attr_reader :cgroup_path

        def read!
          read_from_cgroup!
          read_from_env!
          self
        end

        def self.read!
          new.read!
        end

        def container
          @container ||=
            begin
              return unless container_id
              { id: container_id }
            end
        end

        def kubernetes
          @kubernetes =
            begin
              kubernetes = {
                namespace: kubernetes_namespace,
                node: { name: kubernetes_node_name },
                pod: {
                  name: kubernetes_pod_name,
                  uid: kubernetes_pod_uid
                }
              }
              return nil if kubernetes.values.all?(&:nil?)

              kubernetes
            end
        end

        private

        def read_from_env!
          self.kubernetes_namespace =
            ENV.fetch('KUBERNETES_NAMESPACE', kubernetes_namespace)
          self.kubernetes_node_name =
            ENV.fetch('KUBERNETES_NODE_NAME', kubernetes_node_name)
          self.kubernetes_pod_name =
            ENV.fetch('KUBERNETES_POD_NAME', kubernetes_pod_name)
          self.kubernetes_pod_uid =
            ENV.fetch('KUBERNETES_POD_UID', kubernetes_pod_uid)
        end

        CONTAINER_ID_REGEX = /^[0-9A-Fa-f]{64}$/.freeze
        KUBEPODS_REGEX = %r{(?:^/kubepods/[^/]+/pod([^/]+)$)|(?:^/kubepods\.slice/kubepods-[^/]+\.slice/kubepods-[^/]+-pod([^/]+)\.slice$)}.freeze # rubocop:disable Metrics/LineLength
        SYSTEMD_SCOPE_SUFFIX = '.scope'

        # rubocop:disable Metrics/PerceivedComplexity
        # rubocop:disable Metrics/CyclomaticComplexity
        def read_from_cgroup!
          return unless File.exist?(cgroup_path)
          IO.readlines(cgroup_path).each do |line|
            parts = line.strip.split(':')
            next if parts.length != 3

            cgroup_path = parts[2]

            # Depending on the filesystem driver used for cgroup
            # management, the paths in /proc/pid/cgroup will have
            # one of the following formats in a Docker container:
            #
            #   systemd: /system.slice/docker-<container-ID>.scope
            #   cgroupfs: /docker/<container-ID>
            #
            # In a Kubernetes pod, the cgroup path will look like:
            #
            #   systemd:
            #      /kubepods.slice/kubepods-<QoS-class>.slice/kubepods-\
            #        <QoS-class>-pod<pod-UID>.slice/<container-iD>.scope
            #   cgroupfs:
            #      /kubepods/<QoS-class>/pod<pod-UID>/<container-iD>
            directory, container_id = File.split(cgroup_path)

            if container_id.end_with?(SYSTEMD_SCOPE_SUFFIX)
              container_id = container_id[0...-SYSTEMD_SCOPE_SUFFIX.length]
              if container_id.include?('-')
                container_id = container_id.split('-', 2)[1]
              end
            end

            if (kubepods_match = KUBEPODS_REGEX.match(directory))
              pod_id = kubepods_match[1] || kubepods_match[2]

              self.container_id = container_id
              self.kubernetes_pod_uid = pod_id
            elsif CONTAINER_ID_REGEX.match(container_id)
              self.container_id = container_id
            end
          end
        end
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Metrics/CyclomaticComplexity
      end
    end
  end
end
