# frozen_string_literal: true

module ElasticAPM
  class Metadata
    # @api private
    class SystemInfo
      def initialize
        @architecture = gem_platform.cpu
        @platform = gem_platform.os

        container_info = ContainerInfo.read!
        @container = container_info.container
        @kubernetes = container_info.kubernetes
      end

      attr_reader :architecture, :platform, :container, :kubernetes

      def hostname
        @hostname ||= config.hostname || `hostname`.chomp
      end

      private

      def gem_platform
        @gem_platform ||= Gem::Platform.local
      end

      def config
        ElasticAPM.config
      end
    end
  end
end

require 'elastic_apm/metadata/system_info/container_info'
