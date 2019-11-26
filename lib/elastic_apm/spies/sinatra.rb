# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SinatraSpy
      def install
        ::Sinatra::Base.class_eval do
          alias dispatch_without_apm! dispatch!
          alias compile_template_without_apm compile_template

          def dispatch!(*args, &block)
            dispatch_without_apm!(*args, &block).tap do
              next unless (transaction = ElasticAPM.current_transaction)
              next unless (route = env['sinatra.route'])

              transaction.name = route
            end
          end

          def compile_template(engine, data, opts, *args, &block)
            opts[:__elastic_apm_template_name] =
              case data
              when Symbol then data.to_s
              else format('Inline %s', engine)
              end

            compile_template_without_apm(engine, data, opts, *args, &block)
          end
        end
      end
    end

    register 'Sinatra::Base', 'sinatra/base', SinatraSpy.new

    require 'elastic_apm/spies/tilt'
  end
end
