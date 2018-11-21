# frozen_string_literal: true

module ElasticAPM
  class Metadata
    # @api private
    class ServiceInfo
      # @api private
      class Versioned
        def initialize(name: nil, version: nil)
          @name = name
          @version = version
        end

        attr_reader :name, :version
      end
      class Agent < Versioned; end
      class Framework < Versioned; end
      class Language < Versioned; end
      class Runtime < Versioned; end

      # rubocop:disable Metrics/MethodLength
      def initialize(config)
        @config = config

        @name = @config.service_name
        @environment = @config.environment
        @agent = Agent.new(name: 'ruby', version: VERSION)
        @framework = Framework.new(
          name: @config.framework_name,
          version: @config.framework_version
        )
        @language = Language.new(name: 'ruby', version: RUBY_VERSION)
        @runtime = lookup_runtime
        @version = @config.service_version || Util.git_sha
      end
      # rubocop:enable Metrics/MethodLength

      attr_reader :name, :environment, :agent, :framework, :language, :runtime,
        :version

      private

      # rubocop:disable Metrics/MethodLength
      def lookup_runtime
        case RUBY_ENGINE
        when 'ruby'
          Runtime.new(
            name: RUBY_ENGINE,
            version: RUBY_VERSION || RUBY_ENGINE_VERSION
          )
        when 'jruby'
          Runtime.new(
            name: RUBY_ENGINE,
            version: JRUBY_VERSION || RUBY_ENGINE_VERSION
          )
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
