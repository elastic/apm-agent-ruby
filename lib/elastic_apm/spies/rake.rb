module ElasticAPM
  module Spies
    class RakeSpy
      def install
        ::Rake::Task.class_eval do
          alias orig_execute execute
          def execute(*args)
            ElasticAPM.start
            transaction = ElasticAPM.transaction("Rake::#{name}", "Rake")
            begin
              orig_execute(*args)
              transaction.submit('success') if transaction
            rescue StandardError => e
              transaction.submit(:error) if transaction
              ElasticAPM.report(e)
              raise
            ensure
              transaction.release if transaction
              ElasticAPM.stop
            end
          end
        end
      end
    end
    register 'Rake::Task', 'rake', RakeSpy.new
  end
end

