# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class SidekiqInjector
      # @api private
      class Middleware
        # rubocop:disable Metrics/MethodLength
        def call(_worker, job, queue)
          name = job['class']
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

      def install
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Middleware
          end
        end
      end
    end

    register 'Sidekiq', 'sidekiq', SidekiqInjector.new
  end
end
