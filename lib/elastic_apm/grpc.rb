# frozen_string_literal: true

module ElasticAPM
  # @api private
  class GRPC
    # @api private
    class ClientInterceptor < ::GRPC::ClientInterceptor
      TYPE = 'external'
      SUBTYPE = 'grpc'

      # rubocop:disable Lint/UnusedMethodArgument
      def request_response(request:, call:, method:, metadata:)
        return yield unless (transaction = ElasticAPM.current_transaction)
        if (trace_context = transaction.trace_context)
          trace_context.apply_headers { |k, v| metadata[k.downcase] = v }
        end

        ElasticAPM.with_span(
          method, TYPE,
          subtype: SUBTYPE,
          context: span_context(call)
        ) do
          yield
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument

      private

      def span_context(call)
        peer = call.instance_variable_get(:@wrapped)&.peer
        return unless peer

        split_peer = URI.split(peer)
        destination = ElasticAPM::Span::Context::Destination.new(
          type: TYPE,
          name: SUBTYPE,
          resource: peer,
          address: split_peer[0],
          port: split_peer[6]
        )
        ElasticAPM::Span::Context.new(destination: destination)
      end
    end

    # @api private
    class ServerInterceptor < ::GRPC::ClientInterceptor
      TYPE = 'request'

      # rubocop:disable Lint/UnusedMethodArgument
      def request_response(request:, call:, method:)
        transaction = start_transaction(call)
        yield
        transaction.done 'success'
      rescue ::Exception => e
        ElasticAPM.report(e, handled: false)
        transaction.done 'error'
        raise
      ensure
        ElasticAPM.end_transaction
      end
      # rubocop:enable Lint/UnusedMethodArgument

      private

      def start_transaction(call)
        ElasticAPM.start_transaction(
          'grpc',
          'request',
          trace_context: trace_context(call)
        )
      end

      def trace_context(call)
        TraceContext.parse(metadata: call.metadata)
      rescue TraceContext::InvalidTraceparentHeader
        warn "Couldn't parse invalid trace context header: #{header.inspect}"
        nil
      end
    end
  end
end
