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

require 'elastic_apm/metadata/system_info/container_info'
