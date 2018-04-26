# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class NetHTTPSpy
      # rubocop:disable Metrics/MethodLength
      def install
        Net::HTTP.class_eval do
          alias request_without_apm request

          def request(req, body = nil, &block)
            unless ElasticAPM.current_transaction
              return request_without_apm(req, body, &block)
            end

            host, = req['host'] && req['host'].split(':')
            method = req.method

            host ||= address

            name = "#{method} #{host}"
            type = "ext.net_http.#{method}"

            ElasticAPM.span name, type do
              request_without_apm(req, body, &block)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    register 'Net::HTTP', 'net/http', NetHTTPSpy.new
  end
end
