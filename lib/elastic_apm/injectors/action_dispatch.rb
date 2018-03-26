# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class ActionDispatchInjector
      def install
        ::ActionDispatch::ShowExceptions.class_eval do
          alias render_exception_without_apm render_exception

          def render_exception(env, exception)
            ElasticAPM.report(exception)
            render_exception_without_apm env, exception
          end
        end
      end
    end

    # register(
    #   'ActionDispatch::ShowExceptions',
    #   'action_dispatch/show_exception',
    #   ActionDispatchInjector.new
    # )
  end
end
