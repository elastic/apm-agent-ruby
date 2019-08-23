# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metadata
    def initialize(config)
      @service = ServiceInfo.new(config)
      @process = ProcessInfo.new(config)
      @system = SystemInfo.new(config)
      @labels = config.global_labels
    end

    attr_reader :service, :process, :system, :labels
  end
end

require 'elastic_apm/metadata/service_info'
require 'elastic_apm/metadata/system_info'
require 'elastic_apm/metadata/process_info'
