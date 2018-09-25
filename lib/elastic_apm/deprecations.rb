# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Deprecations
    def deprecate(name, replacement = nil)
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        alias :"#{name}__deprecated" :"#{name}"

        def #{name}(*args, &block)
          warn "[ElasticAPM] [DEPRECATED] `#{name}' is being removed. " \
            "#{replacement && "See `#{replacement}'."}" \
            "\nCalled from \#{caller.first}"
          #{name}__deprecated(*args, &block)
        end
      RUBY
    end
  end
end
