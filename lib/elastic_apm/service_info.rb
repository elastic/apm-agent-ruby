# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ServiceInfo
    def initialize(config)
      @config = config
    end

    # rubocop:disable Metrics/MethodLength
    def build
      base = {
        name: @config.service_name,
        environment: @config.environment,
        agent: {
          name: 'ruby',
          version: VERSION
        },
        framework: nil,
        language: {
          name: 'ruby',
          version: RUBY_VERSION
        },
        runtime: runtime,
        version: @config.service_version || git_sha
      }

      if @config.framework_name
        base[:framework] = {
          name: @config.framework_name,
          version: @config.framework_version
        }
      end

      base
    end
    # rubocop:enable Metrics/MethodLength

    def self.build(config)
      new(config).build
    end

    private

    def runtime
      case RUBY_ENGINE
      when 'ruby'
        { name: RUBY_ENGINE, version: RUBY_VERSION }
      when 'jruby'
        { name: RUBY_ENGINE, version: ENV['JRUBY_VERSION'] }
      end
    end

    def git_sha
      sha = `git rev-parse --verify HEAD 2>&1`.chomp
      $?.success? ? sha : nil # rubocop:disable Style/SpecialGlobalVars
    end
  end
end
