# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class RakeSpy
      module RakeTask
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def execute(*args)
          agent = ElasticAPM.start

          unless agent && agent.config.instrumented_rake_tasks.include?(name)
            return super
          end

          transaction =
            ElasticAPM.start_transaction("Rake::Task[#{name}]", 'Rake')

          begin
            result = super

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

      def install
        Rake::Task.send(:prepend, RakeTask)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
    register 'Rake::Task', 'rake', RakeSpy.new
  end
end
