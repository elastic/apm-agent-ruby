# frozen_string_literal: true

module ElasticAPM
  # @api private

  class GRPC
    # @api private
    class ClientInterceptor < ::GRPC::ClientInterceptor
      def request_response(request:, call:, method:, metadata:)
        # Check if transaction
        # Create span context
        # Create traceparent context
        # Start span
        # yield
        # End span
      end
    end

    # @api private
    class ServerInterceptor < ::GRPC::ServerInterceptor
      def request_response(request:, call:, method:)
        # check if agent is running
        # check if path is ignored
        #   - Is this relevant?
        # start a transaction using info from the args
        binding.pry
        if running? && !path_ignored?(request)
          transaction = start_transaction(request)
        end
        resp = yield
      # Catch error and report it
      rescue ::Exception => e
        context = ElasticAPM.build_context(grpc_request: request, for_type: :error)
        ElasticAPM.report(e, context: context, handled: false)
        raise
      ensure
        if resp && transaction
          status, headers, _body = resp
          # Add response metadata to the transaction
          transaction.add_response(status, headers: headers.dup)
        end
        # End transaction
        ElasticAPM.end_transaction result(status)
      end

      private

      def path_ignored?(requrest)
        return false
        #config.ignore_url_patterns.any? do |r|
        #  env['PATH_INFO'].match r
        #end
      end

      def result(status)
        status && "HTTP #{status.to_s[0]}xx"
      end

      def start_transaction(request:, call:)
        # build context (see ContextBuilder#build)
        #    - What context info to use?
        context = ElasticAPM.build_context(grpc_request: request, for_type: :transaction)

        # extract traceparent from header
        ElasticAPM.start_transaction 'GRPC', 'request',
                                     context: context,
                                     trace_context: trace_context(call)
      end

      def trace_context(call)
        return unless (header = call['HTTP_ELASTIC_APM_TRACEPARENT'])
        TraceContext.parse(header)
      rescue TraceContext::InvalidTraceparentHeader
        warn "Couldn't parse invalid traceparent header: #{header.inspect}"
        nil
      end

      def running?
        ElasticAPM.running?
      end
    end
  end
end
