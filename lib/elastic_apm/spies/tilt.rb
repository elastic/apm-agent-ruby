# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class TiltSpy
      TYPE = 'template.tilt'

      def install
        ::Tilt::Template.class_eval do
          alias render_without_apm render

          def render(*args, &block)
            name = options[:__elastic_apm_template_name] || 'Unknown template'

            ElasticAPM.with_span name, TYPE do
              render_without_apm(*args, &block)
            end
          end
        end
      end
    end

    register 'Tilt::Template', 'tilt/template', TiltSpy.new
  end
end
