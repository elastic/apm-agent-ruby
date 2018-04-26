# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SidekiqSpy
      ACTIVE_JOB_WRAPPER =
        'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper'.freeze

      # @api private
      class Middleware
        # rubocop:disable Metrics/MethodLength
        def call(_worker, job, queue)
          name = SidekiqSpy.name_for(job)
          transaction = ElasticAPM.transaction(name, 'Sidekiq')
          ElasticAPM.set_tag(:queue, queue)

          yield

          transaction.submit('success') if transaction
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction.submit(:error) if transaction
          raise
        ensure
          transaction.release if transaction
        end
        # rubocop:enable Metrics/MethodLength
      end

      def self.name_for(job)
        klass = job['class']

        case klass
        when ACTIVE_JOB_WRAPPER
          job['wrapped']
        else
          klass
        end
      end

      def install_middleware
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Middleware
          end
        end
      end

      # rubocop:disable Metrics/MethodLength
      def install_processor
        require 'sidekiq/processor'

        Sidekiq::Processor.class_eval do
          alias start_without_apm start
          alias terminate_without_apm terminate

          def start
            result = start_without_apm
            ElasticAPM.start # might already be running from railtie

            return result unless ElasticAPM.running?
            ElasticAPM.agent.config.logger = Sidekiq.logger

            result
          end

          def terminate
            terminate_without_apm

            ElasticAPM.stop
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      def install
        install_processor
        install_middleware
      end
    end

    register 'Sidekiq', 'sidekiq', SidekiqSpy.new
  end
end
