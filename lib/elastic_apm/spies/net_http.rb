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
            method = req.method
            path, query = req.path.split('?')

            cls = use_ssl? ? URI::HTTPS : URI::HTTP
            uri = cls.build([nil, host, port, path, query, nil])

            ElasticAPM.with_span(
              "#{method} #{host}",
              TYPE,
              subtype: SUBTYPE,
              action: method.to_s,
              context: ElasticAPM::Span::Context.from_uri(uri)
            ) do |span|
              trace_context = span&.trace_context || transaction.trace_context
              req['Elastic-Apm-Traceparent'] = trace_context.to_header
              request_without_apm(req, body, &block)
            end
          end
        end
      end
    end

    register 'Net::HTTP', 'net/http', NetHTTPSpy.new
  end
end
