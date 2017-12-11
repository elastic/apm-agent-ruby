# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ServiceInfo
    def initialize(config)
      @config = config
    end

    attr_reader :config

    # rubocop:disable Metrics/MethodLength
    def build
      base = {
        name: config.app_name,
        environment: config.environment,
        agent: {
          name: 'ruby',
          version: VERSION
        },
        framework: nil,
        argv: ARGV,
        language: {
          name: 'ruby',
          version: RUBY_VERSION
        },
        pid: $PID,
        process_title: $PROGRAM_NAME,
        runtime: {
          name: RUBY_ENGINE,
          version: RUBY_VERSION
        },
        version: `git rev-parse --verify HEAD`.chomp
      }

      if config.framework_name
        base[:framework] = {
          name: config.framework_name,
          version: config.framework_version
        }
      end

      base
    end
    # rubocop:enable Metrics/MethodLength

    def self.build(config)
      new(config).build
    end
  end
end
