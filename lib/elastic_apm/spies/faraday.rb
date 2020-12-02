# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

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

        # rubocop:disable Style/ExplicitBlockArgument
        ElasticAPM::Spies::NetHTTPSpy.disable_in do
          yield
        end
        # rubocop:enable Style/ExplicitBlockArgument
      end

      # @api private
      module Ext
        # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        def run_request(method, url, body, headers, &block)
          unless (transaction = ElasticAPM.current_transaction)
            return super(method, url, body, headers, &block)
          end

          uri = URI(build_url(url))

          # If url is set inside block it isn't available until yield,
          # so we temporarily build the request to yield. This could be a
          # problem if the block has side effects as it will be yielded twice
          # ~mikker
          unless uri.host
            tmp_request = build_request(method) do |req|
              yield(req) if block
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

              result = super(method, url, body, headers) do |req|
                trace_context.apply_headers { |k, v| req[k] = v }

                yield req if block
              end

              if (http = span&.context&.http)
                http.status_code = result.status.to_s
              end

              span&.outcome = Span::Outcome.from_http_status(result.status)
              result
            end
          end
        end
        # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      end

      def install
        ::Faraday::Connection.prepend(Ext)
      end
    end

    register 'Faraday', 'faraday', FaradaySpy.new
  end
end
