# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class RakeSpy
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def install
        ::Rake::Task.class_eval do
          alias execute_without_apm execute

          def execute(*args)
            agent = ElasticAPM.start

            unless agent && agent.config.instrumented_rake_tasks.include?(name)
              return execute_without_apm(*args)
            end

            transaction =
              ElasticAPM.start_transaction("Rake::Task[#{name}]", 'Rake')

            begin
              result = execute_without_apm(*args)

              transaction.result = 'success' if transaction
            rescue StandardError => e
              transaction.result = 'error' if transaction
              ElasticAPM.report(e)

              raise
            ensure
              ElasticAPM.end_transaction
              ElasticAPM.stop
            end

            result
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
    register 'Rake::Task', 'rake', RakeSpy.new
  end
end
