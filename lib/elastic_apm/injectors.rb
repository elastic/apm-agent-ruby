# frozen_string_literal: true

require 'active_support/inflector'

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class Registration
      def initialize(const_name, require_paths, injector)
        @const_name = const_name
        @require_paths = Array(require_paths)
        @injector = injector
      end

      attr_reader :const_name, :require_paths, :injector

      def install
        injector.install
      end
    end

    def self.require_hooks
      @require_hooks ||= {}
    end

    def self.installed
      @installed ||= {}
    end

    def self.register(*args)
      registration = Registration.new(*args)

      if const_defined?(registration.const_name)
        installed[registration.const_name] = registration
        registration.install
      else
        register_require_hook registration
      end
    end

    def self.register_require_hook(registration)
      registration.require_paths.each do |path|
        require_hooks[path] = registration
      end
    end

    def self.const_defined?(const_name)
      const = ActiveSupport::Inflector.constantize(const_name)
      !!const
    rescue NameError
      false
    end
  end
end

# @api private
module Kernel
  alias require_without_apm require

  def require(path)
    res = require_without_apm(path)

    begin
      ElasticAPM::Injectors.hook_into(path)
    rescue ::Exception # rubocop:disable Lint/HandleExceptions
    end

    res
  end
end
