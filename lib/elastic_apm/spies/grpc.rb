# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class GRPCSpy
      def install
        # Create ClientInterceptor, ServerInterceptor
        # Register ClientInterceptor, ServerInterceptor
      end

      # @api private
      class ClientInterceptor < GRPC::ClientInterceptor
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
      class ServerInterceptor < GRPC::ServerInterceptor
        def request_response(request:, call:, method:)
          # check if agent is running
          # check if path is ignored
          #   - Is this relevant?
          # start a transaction using info from the args
          # build context (see ContextBuilder#build)
          #    - What context info to use?
          # extract traceparent from header
          # yield
          # Catch error and report it
          # Add response metadata to the transaction
          # End transaction
        end
      end
    end

    register 'GRPC', 'grpc', GRPCSpy.new
  end
end
