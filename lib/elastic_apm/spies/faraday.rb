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

      # rubocop:disable Metrics/CyclomaticComplexity
      def install
        ::Faraday::Connection.class_eval do
          alias run_request_without_apm run_request

          def run_request(method, url, body, headers, &block)
            unless (transaction = ElasticAPM.current_transaction)
              return run_request_without_apm(method, url, body, headers, &block)
            end

            uri = URI(build_url(url))

            # If url is set inside block it isn't available until yield,
            # so we temporarily build the request to yield. This could be a
            # problem if the block has side effects as it will be yielded twice
            # ~mikker
            unless uri.host
              tmp_request = build_request(method) do |req|
                yield(req) if block_given?
              end
              uri = URI(tmp_request.path)
            end

            host = uri.host

            upcased_method = method.to_s.upcase

            destination = ElasticAPM::Span::Context::Destination.from_uri(uri)

            context =
              ElasticAPM::Span::Context.new(
                http: { url: uri, method: upcased_method },
                destination: destination
              )

            ElasticAPM.with_span(
              "#{upcased_method} #{host}",
              TYPE,
              subtype: SUBTYPE,
              action: upcased_method,
              context: context
            ) do |span|
              ElasticAPM::Spies::FaradaySpy.without_net_http do
                trace_context = span&.trace_context || transaction.trace_context

                result =
                  run_request_without_apm(method, url, body, headers) do |req|
                    req['Elastic-Apm-Traceparent'] = trace_context.to_header

                    yield req if block_given?
                  end

                if (http = span&.context&.http)
                  http.status_code = result.status.to_s
                end

                result
              end
            end
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
    end

    register 'Faraday', 'faraday', FaradaySpy.new
  end
end
