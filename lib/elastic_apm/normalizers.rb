# frozen_string_literal: true

module ElasticAPM # :nodoc:
  # @api private
  module Normalizers
    # @api privagte
    class Normalizer
      def initialize(config)
        @config = config
      end

      def self.register(name)
        Normalizers.register(name, self)
      end
    end

    def self.register(name, klass)
      @registered ||= {}
      @registered[name] = klass
    end

    def self.build(config)
      normalizers = @registered.each_with_object({}) do |(name, klass), built|
        built[name] = klass.new(config)
      end

      Collection.new(normalizers)
    end

    # @api private
    class Collection
      # @api private
      class SkipNormalizer
        def initialize; end

        def normalize(*_args)
          :skip
        end

        def stacktrace_top(span); end
        def source_location(payload); end
      end

      def initialize(normalizers)
        @normalizers = normalizers
        @default = SkipNormalizer.new
      end

      def for(name)
        @normalizers.fetch(name) { @default }
      end

      def keys
        @normalizers.keys
      end

      def normalize(transaction, name, payload)
        self.for(name).normalize(transaction, name, payload)
      end

      def stacktrace_top(name, span)
        self.for(name).stacktrace_top(span)
      end

      def source_location(name, payload)
        self.for(name).source_location(payload)
      end
    end
  end
end
