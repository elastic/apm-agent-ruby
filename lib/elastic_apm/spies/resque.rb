# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class ResqueSpy
      ACTIVE_JOB_WRAPPER =
        'ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper'.freeze

      def install
        install_fork_hook
        install_worker_hook
      end

      def self.set_meta(job)
        return unless (transaction = ElasticAPM.current_transaction)

        if job.payload_class_name == ACTIVE_JOB_WRAPPER
          args = job.payload['args'].first
          return unless args

          transaction.name = args['job_class']
          ElasticAPM.set_tag(:queue, args['queue_name'])
        else
          transaction.name = job.payload_class_name
          ElasticAPM.set_tag(:queue, job.queue)
        end
      end

      private

      def install_fork_hook
        ::Resque.before_first_fork do
          ElasticAPM.start(
            # logger: ::Resque.logger,
            logger: Logger.new($stdout),
            debug_transactions: true
          )
        end
      end

      # rubocop:disable Metrics/MethodLength
      def install_worker_hook
        # rubocop:disable Metrics/BlockLength
        ::Resque::Worker.class_eval do
          alias :perform_with_fork_without_elastic_apm :perform_with_fork
          alias :perform_without_elastic_apm :perform

          def perform_with_apm
            transaction = ElasticAPM.transaction nil, 'Resque'
            pp(ID: transaction.object_id)

            begin
              yield

              transaction.submit(:success) if transaction
            rescue Exception => e
              ElasticAPM.report(e, handled: false)
              transaction.submit(:error) if transaction
            ensure
              transaction.release if transaction
            end

            true
          end

          def perform_with_fork(job, &block)
            perform_with_apm do
              ResqueSpy.set_meta(job)

              perform_with_fork_without_elastic_apm(job, &block)
            end
          end

          def perform(job)
            if fork_per_job?
              perform_without_elastic_apm(job)
            else
              perform_with_apm do
                ResqueSpy.set_meta(job)
                perform_without_elastic_apm(job)
              end
            end
          end
        end
        # rubocop:enable Metrics/BlockLength
      end
      # rubocop:enable Metrics/MethodLength
    end

    register 'Resque', 'resque', ResqueSpy.new
  end
end
