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
        version: @config.service_version || Util.git_sha
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
        { name: RUBY_ENGINE, version: RUBY_VERSION || RUBY_ENGINE_VERSION }
      when 'jruby'
        { name: RUBY_ENGINE, version: JRUBY_VERSION || RUBY_ENGINE_VERSION }
      end
    end
  end
end
