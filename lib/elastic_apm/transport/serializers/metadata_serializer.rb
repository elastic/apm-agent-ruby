# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class MetadataSerializer < Serializer
        def build(metadata)
          {
            metadata: {
              service: build_service(metadata.service),
              process: build_process(metadata.process),
              system: build_system(metadata.system),
              labels: build_labels(metadata.labels)
            }
          }
        end

        private

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def build_service(service)
          {
            name: keyword_field(service.name),
            environment: keyword_field(service.environment),
            version: keyword_field(service.version),
            agent: {
              name: keyword_field(service.agent.name),
              version: keyword_field(service.agent.version)
            },
            framework: {
              name: keyword_field(service.framework.name),
              version: keyword_field(service.framework.version)
            },
            language: {
              name: keyword_field(service.language.name),
              version: keyword_field(service.language.version)
            },
            runtime: {
              name: keyword_field(service.runtime.name),
              version: keyword_field(service.runtime.version)
            }
          }
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def build_process(process)
          {
            pid: process.pid,
            title: keyword_field(process.title),
            argv: process.argv
          }
        end

        def build_system(system)
          {
            hostname: keyword_field(system.hostname),
            architecture: keyword_field(system.architecture),
            platform: keyword_field(system.platform),
            kubernetes: keyword_object(system.kubernetes)
          }
        end

        def build_labels(labels)
          keyword_object(labels)
        end
      end
    end
  end
end
