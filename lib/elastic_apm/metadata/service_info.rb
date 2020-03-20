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
      def initialize(
        service_name:,
        framework_name:,
        framework_version:,
        service_version:
      )
        @name = service_name
        @agent = Agent.new(name: 'ruby', version: VERSION)
        @framework = Framework.new(
          name: framework_name,
          version: framework_version
        )
        @language = Language.new(name: 'ruby', version: RUBY_VERSION)
        @runtime = lookup_runtime
        @version = service_version || Util.git_sha
      end

      attr_reader :name, :agent, :framework, :language, :runtime,
        :version

      def environment
        # This value can be changed in the remote config so we
        # get it via ElasticAPM
        ElasticAPM.config.environment
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
    end
  end
end
