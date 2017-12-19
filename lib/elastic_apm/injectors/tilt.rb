# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class TiltInjector
      TYPE = 'template.tilt'.freeze

      def install
        ::Tilt::Template.class_eval do
          alias render_without_apm render

          def render(*args, &block)
            name = options[:__elastic_apm_template_name] || 'Unknown template'

            ElasticAPM.span name, TYPE do
              render_without_apm(*args, &block)
            end
          end
        end
      end
    end

    register 'Tilt::Template', 'tilt/template', TiltInjector.new
  end
end
