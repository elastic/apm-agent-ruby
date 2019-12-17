# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    module ActionController
      # @api private
      class BasicImplicitRenderSpy
        def install
          ::ActionController::BasicImplicitRender.module_eval do
            alias send_action_without_apm send_action

            def send_action(method_name, *args)
              ElasticAPM.current_span&.original_backtrace ||= caller
              send_action_without_apm method_name, *args
            end
          end
        end
      end
    end

    register(
      'ActionController::BasicImplicitRender',
      'action_controller/metal/basic_implicit_render',
      ActionController::BasicImplicitRenderSpy.new
    )
  end
end
