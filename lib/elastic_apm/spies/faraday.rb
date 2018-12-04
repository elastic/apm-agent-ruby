# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class FaradaySpy
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def install
        ::Faraday::Connection.class_eval do
          alias run_request_without_apm run_request

          def run_request(method, url, body, headers, &block)
            unless (transaction = ElasticAPM.current_transaction)
              return run_request_without_apm(method, url, body, headers, &block)
            end

            host = URI(url).host

            name = "#{method.upcase} #{host}"
            type = "ext.faraday.#{method}"

            ElasticAPM.with_span name, type do |span|
              ElasticAPM::Spies::NetHTTPSpy.disable_in do
                id = span&.id || transaction.id

                run_request_without_apm(method, url, body, headers) do |req|
                  req['Elastic-Apm-Traceparent'] =
                    transaction.traceparent.to_header(span_id: id)

                  yield req if block_given?
                end
              end
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end

    register 'Faraday', 'faraday', FaradaySpy.new
  end
end
