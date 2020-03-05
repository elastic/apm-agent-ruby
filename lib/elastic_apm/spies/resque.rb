# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class ResqueSpy
      TYPE = 'Resque'

      def install
        install_perform_spy
        install_after_fork_hook
      end

      def install_after_fork_hook
        ::Resque.after_fork do
          ElasticAPM.restart
        end
      end

      def install_perform_spy
        ::Resque::Job.class_eval do
          alias :perform_without_elastic_apm :perform

          def perform
            ElasticAPM.with_transaction(nil, TYPE) do
              perform_without_elastic_apm
            end
          end
        end
      end
    end

    register 'Resque', 'resque', ResqueSpy.new
  end
end
