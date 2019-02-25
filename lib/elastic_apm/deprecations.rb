# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Deprecations
    def deprecate(name, replacement = nil)
      alias_name = "#{name.to_s.chomp('=')}__deprecated_"
      alias_name += '=' if name.to_s.end_with?('=')

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        alias :"#{alias_name}" :"#{name}"

        def #{name}(*args, &block)
          warn "[ElasticAPM] [DEPRECATED] `#{name}' is being removed. " \
               "#{replacement && "See `#{replacement}'."}" \
               "\nCalled from \#{caller.first}"
          send("#{alias_name}", *args, &block)
        end
      RUBY
    end
  end
end
