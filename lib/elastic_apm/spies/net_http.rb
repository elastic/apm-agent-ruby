# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class NetHTTPSpy
      KEY = :__elastic_apm_net_http_disabled
      TYPE = 'ext'
      SUBTYPE = 'net_http'

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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

            host, = req['host'] && req['host'].split(':')
            method = req.method

            host ||= address

            name = "#{method} #{host}"

            ElasticAPM.with_span(
              name,
              TYPE,
              subtype: SUBTYPE,
              action: method.to_s
            ) do |span|
              trace_context = span&.trace_context || transaction.trace_context
              req['Elastic-Apm-Traceparent'] = trace_context.to_header
              request_without_apm(req, body, &block)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end

    register 'Net::HTTP', 'net/http', NetHTTPSpy.new
  end
end
