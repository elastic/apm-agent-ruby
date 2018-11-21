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
      end

      attr_reader :hostname, :architecture, :platform

      private

      def gem_platform
        @gem_platform ||= Gem::Platform.local
      end
    end
  end
end
