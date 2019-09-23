# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class FaradaySpy
      TYPE = 'ext'
      SUBTYPE = 'faraday'

      def self.without_net_http
        return yield unless defined?(NetHTTPSpy)

        ElasticAPM::Spies::NetHTTPSpy.disable_in do
          yield
        end
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      # rubocop:disable Metrics/BlockLength, Metrics/PerceivedComplexity
      # rubocop:disable Metrics/CyclomaticComplexity
      def install
        ::Faraday::Connection.class_eval do
          alias run_request_without_apm run_request

          def run_request(method, url, body, headers, &block)
            unless (transaction = ElasticAPM.current_transaction)
              return run_request_without_apm(method, url, body, headers, &block)
            end

            host = if url_prefix.is_a?(URI) && url_prefix.host
                     url_prefix.host
                   elsif url.nil?
                     tmp_request = build_request(method) do |req|
                       yield(req) if block_given?
                     end
                     URI(tmp_request.path).host
                   else
                     URI(url).host
                   end

            name = "#{method.upcase} #{host}"

            ElasticAPM.with_span(
              name,
              TYPE,
              subtype: SUBTYPE,
              action: method.to_s
            ) do |span|
              ElasticAPM::Spies::FaradaySpy.without_net_http do
                trace_context = span&.trace_context || transaction.trace_context

                run_request_without_apm(method, url, body, headers) do |req|
                  req['Elastic-Apm-Traceparent'] = trace_context.to_header

                  yield req if block_given?
                end
              end
            end
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/BlockLength, Metrics/PerceivedComplexity
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end

    register 'Faraday', 'faraday', FaradaySpy.new
  end
end
