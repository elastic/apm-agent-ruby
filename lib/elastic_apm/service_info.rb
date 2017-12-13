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
        runtime: runtime,
        version: git_sha
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

    private

    def git_sha
      sha = `git rev-parse --verify HEAD 2>&1`.chomp
      return sha if $?.success? # rubocop:disable Style/SpecialGlobalVars

      nil
    end

    def runtime
      case RUBY_ENGINE
      when 'ruby'
        { name: RUBY_ENGINE, version: RUBY_VERSION }
      when 'jruby'
        { name: 'jruby', version: ENV['JRUBY_VERSION'] }
      end
    end
  end
end
