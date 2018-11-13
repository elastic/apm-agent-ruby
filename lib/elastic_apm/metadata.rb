# frozen_string_literal: true

require 'elastic_apm/metadata/service_info'
require 'elastic_apm/metadata/system_info'
require 'elastic_apm/metadata/process_info'

module ElasticAPM
  # @api private
  module Metadata
    def self.build(config)
      {
        metadata: {
          service: Metadata::ServiceInfo.build(config),
          process: Metadata::ProcessInfo.build(config),
          system: Metadata::SystemInfo.build(config)
        }
      }.to_json
    end
  end
end
