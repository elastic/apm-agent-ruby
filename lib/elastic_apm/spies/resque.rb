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
            name = @payload && @payload['class']&.name
            transaction = ElasticAPM.start_transaction(name, TYPE)
            perform_without_elastic_apm
            transaction.done 'success'
          rescue ::Exception => e
            ElasticAPM.report(e, handled: false)
            transaction.done 'error'
            raise
          ensure
            ElasticAPM.end_transaction
          end
        end
      end
    end

    register 'Resque', 'resque', ResqueSpy.new
  end
end
