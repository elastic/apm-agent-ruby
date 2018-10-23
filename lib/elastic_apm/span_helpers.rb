# frozen_string_literal: true

module ElasticAPM
  # @api private
  module SpanHelpers
    # @api private
    module ClassMethods
      def span_class_method(method, name = nil, type = nil)
        __span_method_on(singleton_class, method, name, type)
      end

      def span_method(method, name = nil, type = nil)
        __span_method_on(self, method, name, type)
      end

      private

      def __span_method_on(klass, method, name = nil, type = nil)
        name ||= method.to_s
        type ||= Span::DEFAULT_TYPE

        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          alias :"__without_apm_#{method}" :"#{method}"

          def #{method}(*args, &block)
            unless ElasticAPM.current_transaction
              return __without_apm_#{method}(*args, &block)
            end

            ElasticAPM.with_span "#{name}", "#{type}" do
              __without_apm_#{method}(*args, &block)
            end
          end
        RUBY
      end
    end

    def self.included(kls)
      kls.class_eval do
        extend ClassMethods
      end
    end
  end
end
