# frozen_string_literal: true

require 'net/http'

# @api private
module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class NetHTTPInjector
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def install
        Net::HTTP.class_eval do
          alias request_without_apm request

          def request(req, body = nil, &block)
            unless ElasticAPM.current_transaction
              return request_without_apm(req, body, &block)
            end

            host, port = req['host'] && req['host'].split(':')
            method = req.method
            path = req.path
            scheme = use_ssl? ? 'https' : 'http'

            # inside a session
            host ||= address
            port ||= 80

            extra = {
              scheme: scheme,
              port: port,
              path: path
            }

            name = "#{method} #{host}"
            type = "ext.net_http.#{method}"

            ElasticAPM.trace name, type, extra do
              request_without_apm(req, body, &block)
            end
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end

    register 'Net::HTTP', 'net/http', NetHTTPInjector.new
  end
end
