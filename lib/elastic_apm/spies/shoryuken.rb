# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class ShoryukenSpy
      # @api private
      class Middleware
        def call(worker_instance, queue, sqs_msg, body)
          transaction =
            ElasticAPM.start_transaction(
              job_class(worker_instance, body),
              'shoryuken.job'
            )

          ElasticAPM.set_label('shoryuken.id', sqs_msg.message_id)
          ElasticAPM.set_label('shoryuken.queue', queue)

          yield

          transaction&.done :success
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction&.done :error
          raise
        ensure
          ElasticAPM.end_transaction
        end

        private

        def job_class(worker_instance, body)
          klass = body['job_class'] if body.is_a?(Hash)
          klass || worker_instance.class.name
        end
      end

      def install
        ::Shoryuken.server_middleware do |chain|
          chain.add Middleware
        end
      end
    end

    register 'Shoryuken', 'shoryuken', ShoryukenSpy.new
  end
end
