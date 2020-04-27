# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SuckerPunchSpy
      TYPE = 'sucker_punch'

      def install
        ::SuckerPunch::Job::ClassMethods.class_eval do
          alias :__run_perform_without_elastic_apm :__run_perform

          def __run_perform(*args)
            # This method is reached via JobClass#async_perform
            # or JobClass#perform_in.
            name = to_s
            transaction = ElasticAPM.start_transaction(name, TYPE)
            __run_perform_without_elastic_apm(*args)
            transaction.done 'success'
          rescue ::Exception => e
            # Note that SuckerPunch by default doesn't raise the errors from
            # the user-defined JobClass#perform method as it uses an error
            # handler, accessed via `SuckerPunch.exception_handler`.
            ElasticAPM.report(e, handled: false)
            transaction.done 'error'
            raise
          ensure
            ElasticAPM.end_transaction
          end
        end
      end
    end

    register 'SuckerPunch', 'sucker_punch', SuckerPunchSpy.new
  end
end
