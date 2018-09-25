# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class NetHTTPSpy
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def install
        Net::HTTP.class_eval do
          alias request_without_apm request

          def request(req, body = nil, &block)
            unless (transaction = ElasticAPM.current_transaction)
              return request_without_apm(req, body, &block)
            end

            host, = req['host'] && req['host'].split(':')
            method = req.method

            host ||= address

            name = "#{method} #{host}"
            type = "ext.net_http.#{method}"

            ElasticAPM.with_span name, type do |span|
              req['Elastic-Apm-Traceparent'] =
                transaction.traceparent.to_header(span_id: span.id)

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
