# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Deprecations
    def deprecate(name, replacement = nil)
      type = name.to_s.end_with?('=') ? 'set' : 'get'
      send("deprecate_#{type}", name, replacement)
    end

    def deprecate_get(name, replacement)
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

    def deprecate_set(name, replacement)
      alias_name = "#{name.to_s.chomp('=')}__deprecated="
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        alias :#{alias_name} :"#{name}"

        def #{name}(val)
          warn "[ElasticAPM] [DEPRECATED] `#{name}' is being removed. " \
               "#{replacement && "See `#{replacement}'."}" \
               "\nCalled from \#{caller.first}"
          self.#{alias_name}(val)
        end
      RUBY
    end
  end
end
