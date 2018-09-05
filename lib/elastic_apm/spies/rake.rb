# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class RakeSpy
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      # rubocop:disable Metrics/CyclomaticComplexity
      def install
        ::Rake::Task.class_eval do
          alias execute_without_apm execute

          def execute(*args)
            agent = ElasticAPM.start

            unless agent && agent.config.instrumented_rake_tasks.include?(name)
              return execute_without_apm(*args)
            end

            transaction = ElasticAPM.transaction("Rake::Task[#{name}]", 'Rake')

            begin
              result = execute_without_apm(*args)

              transaction.submit('success') if transaction
            rescue StandardError => e
              transaction.submit(:error) if transaction
              ElasticAPM.report(e)

              raise
            ensure
              transaction.release if transaction
              ElasticAPM.stop
            end

            result
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
    register 'Rake::Task', 'rake', RakeSpy.new
  end
end
