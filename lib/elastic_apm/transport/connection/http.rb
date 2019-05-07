# frozen_string_literal: true

require 'http'
require 'concurrent'
require 'zlib'

require 'elastic_apm/transport/connection/proxy_pipe'

module ElasticAPM
  module Transport
    class Connection
      # @api private
      class Http
        include Logging

        def initialize(config)
          @config = config
          @closed = Concurrent::AtomicBoolean.new

          @rd, @wr = ProxyPipe.pipe(compress: @config.http_compression?)
        end

        def open(url, headers: {}, ssl_context: nil)
          @request = open_request_in_thread(url, headers, ssl_context)
        end

        def self.open(config, url, headers: {}, ssl_context: nil)
          new(config).tap do |http|
            http.open(url, headers: headers, ssl_context: ssl_context)
          end
        end

        def write(str)
          @wr.write(str)
          @wr.bytes_sent
        end

        def close(reason)
          return if closed?

          debug '%s: Closing request with reason %s', thread_str, reason
          @closed.make_true

          @wr&.close(reason)
          return if @request.nil? || @request&.join(5)

          error(
            '%s: APM Server not responding in time, terminating request',
            thread_str
          )
          @request.kill
        end

        def closed?
          @closed.true?
        end

        def inspect
          format(
            '%s closed: %s>',
            super.split.first,
            closed?
          )
        end

        private

        def thread_str
          format('[THREAD:%s]', Thread.current.object_id)
        end

        # rubocop:disable Metrics/LineLength
        def open_request_in_thread(url, headers, ssl_context)
          client = build_client(headers)

          debug '%s: Opening new request', thread_str
          Thread.new do
            begin
              post(client, url, ssl_context)
            rescue Exception => e
              error "Couldn't establish connection to APM Server:\n%p", e.inspect
            end
          end
        end
        # rubocop:enable Metrics/LineLength

        def build_client(headers)
          client = HTTP.headers(headers)
          return client unless @config.proxy_address && @config.proxy_port

          client.via(
            @config.proxy_address,
            @config.proxy_port,
            @config.proxy_username,
            @config.proxy_password,
            @config.proxy_headers
          )
        end

        def post(client, url, ssl_context)
          resp = client.post(
            url,
            body: @rd,
            ssl_context: ssl_context
          ).flush

          if resp&.status == 202
            debug 'APM Server responded with status 202'
          elsif resp
            error "APM Server responded with an error:\n%p", resp.body.to_s
          end
        end
      end
    end
  end
end
