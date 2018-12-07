# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class HTTPSpy
      # rubocop:disable Metrics/MethodLength
      def install
        ::HTTP::Client.class_eval do
          alias perform_without_apm perform

          def perform(req, options)
            unless (transaction = ElasticAPM.current_transaction)
              return perform_without_apm(req, options)
            end

            method = req.verb.to_s.upcase
            host = req.uri.host

            name = "#{method} #{host}"
            type = "ext.http_rb.#{method}"

            ElasticAPM.with_span name, type do |span|
              trace_context = span&.trace_context || transaction.trace_context
              req['Elastic-Apm-Traceparent'] = trace_context.to_header
              perform_without_apm(req, options)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    register 'HTTP', 'http', HTTPSpy.new
  end
end
