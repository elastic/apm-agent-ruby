# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class NetHTTPSpy
      KEY = :__elastic_apm_net_http_disabled

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

      module Overrides
        # @api private
        def request(req, body = nil)
          return super if ElasticAPM::Spies::NetHTTPSpy.disabled?

          transaction = ElasticAPM.current_transaction
          return super unless transaction

          host, = req['host'] && req['host'].split(':')
          method = req.method

          host ||= address

          name = "#{method} #{host}"
          type = "ext.net_http.#{method}"

          ElasticAPM.with_span name, type do |span|
            trace_context = span&.trace_context || transaction.trace_context
            req['Elastic-Apm-Traceparent'] = trace_context.to_header
            super
          end
        end
      end

      def install
        Net::HTTP.class_eval do
          prepend Overrides
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end

    register 'Net::HTTP', 'net/http', NetHTTPSpy.new
  end
end
