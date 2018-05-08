# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class ResqueSpy
      def install
        install_fork_hook
        install_job_hook
      end

      private

      def install_fork_hook
        ::Resque.before_first_fork do
          puts "Thread:#{Thread.current.object_id}"
          ElasticAPM.start(
            logger: Logger.new($stdout),
            debug_transactions: true
          )
        end
      end

      def install_job_hook
        ::Resque::Job.class_eval do
          alias :payload_class_without_elastic_apm :payload_class

          def payload_class
            original = payload_class_without_elastic_apm
            original.extend(Hooks)
            original
          end
        end
      end

      # @api private
      module Hooks
        TYPE = 'Resque'.freeze

        # rubocop:disable Metrics/MethodLength
        def around_perform_with_elastic_apm(*_args)
          transaction = ElasticAPM.transaction 'Job', TYPE

          begin
            yield

            transaction.submit(:success) if transaction
          rescue Exception => e
            ElasticAPM.report(e, handled: false)
            transaction.submit(:error) if transaction
            raise
          ensure
            transaction.release if transaction
          end
        end
        # rubocop:enable Metrics/MethodLength
      end
    end

    register 'Resque', 'resque', ResqueSpy.new
  end
end
