# frozen_string_literal: true

module ElasticAPM
  # @api private
  class GRPC
    # @api private
    class ClientInterceptor < ::GRPC::ClientInterceptor
      TYPE = 'external.grpc'

      # rubocop:disable Lint/UnusedMethodArgument
      def request_response(request:, call:, method:, metadata:)
        return yield unless (transaction = ElasticAPM.current_transaction)
        if (trace_context = transaction.trace_context)
          metadata['elastic-apm-traceparent'] = trace_context.to_header
        end
        ElasticAPM.with_span(method, TYPE) do
          yield
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
