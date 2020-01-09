# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class HTTPSpy
      TYPE = 'ext'
      SUBTYPE = 'http_rb'
      def install
        ::HTTP::Client.class_eval do
          alias perform_without_apm perform

          def perform(req, options)
            unless (transaction = ElasticAPM.current_transaction)
              return perform_without_apm(req, options)
            end

            method = req.verb.to_s.upcase
            host = req.uri.host

            destination =
              ElasticAPM::Span::Context::Destination.from_uri(req.uri)
            context = ElasticAPM::Span::Context.new(
              http: { url: req.uri, method: method },
              destination: destination
            )

            name = "#{method} #{host}"

            ElasticAPM.with_span(
              name,
              TYPE,
              subtype: SUBTYPE,
              action: method,
              context: context
            ) do |span|
              trace_context = span&.trace_context || transaction.trace_context
              req['Elastic-Apm-Traceparent'] = trace_context.to_header
              result = perform_without_apm(req, options)

              if (http = span&.context&.http)
                http.status_code = result.status.to_s
              end

              result
            end
          end
        end
      end
    end

    register 'HTTP', 'http', HTTPSpy.new
  end
end
