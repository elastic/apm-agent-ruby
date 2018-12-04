# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class HTTPSpy
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def install
        ::HTTP::Client.class_eval do
          alias perform_without_apm perform

          def perform(req, options)
            unless (transaction = ElasticAPM.current_transaction)
              return perform_without_apm(req, options)
            end

            method = req.verb.to_s.upcase
            host = req.uri.host

            name = "#{method} #{host}"
            type = "ext.http_rb.#{method}"

            ElasticAPM.with_span name, type do |span|
              id = span&.id || transaction.id

              req['Elastic-Apm-Traceparent'] =
                transaction.traceparent.to_header(span_id: id)

              perform_without_apm(req, options)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end

    register 'HTTP', 'http', HTTPSpy.new
  end
end
