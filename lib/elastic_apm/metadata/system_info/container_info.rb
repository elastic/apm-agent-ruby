# frozen_string_literal: true

module ElasticAPM
  class Metadata
    class SystemInfo
      # @api private
      class ContainerInfo
        CGROUP_PATH = '/proc/pid/cgroup'

        attr_accessor :container_id, :kupernetes_namespace,
          :kupernetes_node_name, :kupernetes_pod_name, :kupernetes_pod_uid

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

        def kupernetes
          @kupernetes =
            begin
              kupernetes = {}

              kupernetes[:namespace] = kupernetes_namespace
              kupernetes[:node_name] = kupernetes_node_name
              kupernetes[:pod_name] = kupernetes_pod_name
              kupernetes[:pod_uid] = kupernetes_pod_uid
              return nil if kupernetes.values.all?(&:nil?)

              kupernetes
            end
        end

        private

        def read_from_env!
          self.kupernetes_namespace =
            ENV.fetch('KUBERNETES_NAMESPACE', kupernetes_namespace)
          self.kupernetes_node_name =
            ENV.fetch('KUBERNETES_NODE_NAME', kupernetes_node_name)
          self.kupernetes_pod_name =
            ENV.fetch('KUBERNETES_POD_NAME', kupernetes_pod_name)
          self.kupernetes_pod_uid =
            ENV.fetch('KUBERNETES_POD_UID', kupernetes_pod_uid)
        end

        CONTAINER_ID_REGEX = /^[0-9A-Fa-f]{64}$/.freeze
        KUBEPODS_REGEX = %r{(?:^/kubepods/[^/]+/pod([^/]+)$)|(?:^/kubepods\.slice/kubepods-[^/]+\.slice/kubepods-[^/]+-pod([^/]+)\.slice$)}.freeze # rubocop:disable Metrics/LineLength
        SYSTEMD_SCOPE_SUFFIX = '.scope'

        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize
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
              self.kupernetes_pod_uid = pod_id
            elsif CONTAINER_ID_REGEX.match(container_id)
              self.container_id = container_id
            end
          end
        end
        # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/AbcSize
      end
    end
  end
end
