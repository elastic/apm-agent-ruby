# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class ActionDispatchSpy
      def install
        ::ActionDispatch::ShowExceptions.class_eval do
          alias render_exception_without_apm render_exception

          def render_exception(env, exception)
            context = ElasticAPM.build_context(rack_env: env, for_type: :error)
            ElasticAPM.report(exception, context: context, handled: false)

            render_exception_without_apm env, exception
          end
        end
      end
    end

    register(
      'ActionDispatch::ShowExceptions',
      'action_dispatch/show_exception',
      ActionDispatchSpy.new
    )
  end
end
