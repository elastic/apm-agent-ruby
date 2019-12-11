# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class NetHTTPSpy
      KEY = :__elastic_apm_net_http_disabled
      TYPE = 'ext'
      SUBTYPE = 'net_http'

      class << self
        def disabled=(disabled)
          Thread.current[KEY] = disabled
        end

        def disabled?
          Thread.current[KEY] ||= false
        end

        def disable_in
          self.disabled = true

          begin
            yield
          ensure
            self.disabled = false
          end
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def install
        Net::HTTP.class_eval do
          alias request_without_apm request

          def request(req, body = nil, &block)
            unless (transaction = ElasticAPM.current_transaction)
              return request_without_apm(req, body, &block)
            end

            if ElasticAPM::Spies::NetHTTPSpy.disabled?
              return request_without_apm(req, body, &block)
            end

            host = req['host']&.split(':')&.first || address
            method = req.method.to_s.upcase
            path, query = req.path.split('?')

            cls = use_ssl? ? URI::HTTPS : URI::HTTP
            uri = cls.build([nil, host, port, path, query, nil])

            destination =
              ElasticAPM::Span::Context::Destination.from_uri(uri)

            context =
              ElasticAPM::Span::Context.new(
                http: { url: uri, method: method },
                destination: destination
              )

            ElasticAPM.with_span(
              "#{method} #{host}",
              TYPE,
              subtype: SUBTYPE,
              action: method,
              context: context
            ) do |span|
              trace_context = span&.trace_context || transaction.trace_context
              req['Elastic-Apm-Traceparent'] = trace_context.to_header
              result = request_without_apm(req, body, &block)

              if (http = span&.context&.http)
                http.status_code = result.code
              end

              result
            end
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
    end

    register 'Net::HTTP', 'net/http', NetHTTPSpy.new
  end
end
