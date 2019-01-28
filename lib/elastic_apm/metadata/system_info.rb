# frozen_string_literal: true

module ElasticAPM
  class Metadata
    # @api private
    class SystemInfo
      def initialize(config)
        @config = config

        @hostname = @config.hostname || `hostname`.chomp
        @architecture = gem_platform.cpu
        @platform = gem_platform.os

        container_info = ContainerInfo.read!
        @container = container_info.container
        @kupernetes = container_info.kupernetes
      end

      attr_reader :hostname, :architecture, :platform, :container, :kupernetes

      private

      def gem_platform
        @gem_platform ||= Gem::Platform.local
      end
    end
  end
end

module ElasticAPM
  class Metadata
    class SystemInfo
      # @api private
      class ContainerInfo
        CGROUP_PATH = '/proc/pid/cgroup'

        attr_accessor :container_id, :kupernetes_namespace,
          :kupernetes_node_name, :kupernetes_pod_name, :kupernetes_pod_uid

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
          self.kupernetes_namespace = ENV.fetch('KUBERNETES_NAMESPACE', nil)
          self.kupernetes_node_name = ENV.fetch('KUBERNETES_NODE_NAME', nil)
          self.kupernetes_pod_name = ENV.fetch('KUBERNETES_POD_NAME', nil)
          self.kupernetes_pod_uid = ENV.fetch('KUBERNETES_POD_UID', nil)
        end

        def read_from_cgroup!
          return unless File.exist?(CGROUP_PATH)
          pp IO.readlines(CGROUP_PATH)
        end
      end
    end
  end
end
