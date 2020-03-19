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

      class Framework
        def name
          @name ||= ElasticAPM.config.framework_name
        end

        def version
          @version ||= ElasticAPM.config.framework_version
        end
      end

      class Agent < Versioned; end
      class Language < Versioned; end
      class Runtime < Versioned; end
      def initialize
        @agent = Agent.new(name: 'ruby', version: VERSION)
        @framework = Framework.new
        @language = Language.new(name: 'ruby', version: RUBY_VERSION)
        @runtime = lookup_runtime
      end

      attr_reader :environment, :agent, :framework, :language, :runtime

      def environment
        config.environment
      end

      def name
        @name ||= config.service_name
      end

      def version
        @version ||= config.service_version || Util.git_sha
      end

      private

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

      def config
        ElasticAPM.config
      end
    end
  end
end
