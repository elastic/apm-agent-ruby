# frozen_string_literal: true

require 'elastic_apm/util/inflector'

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class Registration
      extend Forwardable

      def initialize(const_name, require_paths, spy)
        @const_name = const_name
        @require_paths = Array(require_paths)
        @spy = spy
      end

      attr_reader :const_name, :require_paths

      def_delegator :@spy, :install
    end

    def self.require_hooks
      @require_hooks ||= {}
    end

    def self.installed
      @installed ||= {}
    end

    def self.register(*args)
      registration = Registration.new(*args)

      if safe_defined?(registration.const_name)
        registration.install
        installed[registration.const_name] = registration
      else
        register_require_hook registration
      end
    end

    def self.register_require_hook(registration)
      registration.require_paths.each do |path|
        require_hooks[path] = registration
      end
    end

    def self.hook_into(name)
      return unless (registration = require_hooks[name])
      return unless safe_defined?(registration.const_name)

      installed[registration.const_name] = registration
      registration.install

      registration.require_paths.each do |path|
        require_hooks.delete path
      end
    end

    def self.safe_defined?(const_name)
      Util::Inflector.safe_constantize(const_name)
    end
  end
end

# @api private
module Kernel
  private

  alias require_without_apm require

  def require(path)
    res = require_without_apm(path)

    begin
      ElasticAPM::Spies.hook_into(path)
    rescue ::Exception => e
      puts "Failed hooking into '#{path}'. Please report this at " \
        'github.com/elastic/apm-agent-ruby'
      puts e.backtrace.join("\n")
    end

    res
  end
end
