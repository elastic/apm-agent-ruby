# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metadata
    def initialize(config)
      @service = ServiceInfo.new(
        service_name: config.service_name,
        framework_name: config.framework_name,
        framework_version: config.framework_version,
        service_version: config.service_version
      )
      @process = ProcessInfo.new
      @system = SystemInfo.new(hostname: config.hostname)
      @labels = config.global_labels
    end

    attr_reader :service, :process, :system, :labels
  end
end

require 'elastic_apm/metadata/service_info'
require 'elastic_apm/metadata/system_info'
require 'elastic_apm/metadata/process_info'
