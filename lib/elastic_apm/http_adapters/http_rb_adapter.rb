require 'elastic_apm/http_adapters/abstract_adapter'
begin
  require 'http'

  module ElasticAPM
    module HttpAdapters
      # @api private
      class HttpRbAdapter < AbstractHttpAdapter
        def perform(uri, data, headers)
          return DISABLED if @config.disable_send?

          req = client(uri).headers(headers)
          if @config.http_compression &&
            data.bytesize > @config.compression_minimum_size
            req = req.use(auto_deflate: { method: :deflate })
          end
          Response.new req.post(uri, body: data, ssl_context: get_context)
        end

        private

        def client(uri)
          @client ||= begin
            keepalive = @config.http_adapter_options[:keepalive]
            keepalive ? ::HTTP.persistent(uri) : ::HTTP
          end
        end

        def get_context
          ctx = OpenSSL::SSL::SSLContext.new
          if @config.use_ssl? && @config.verify_server_cert?
            ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          ctx
        end
      end
    end
  end
rescue LoadError
end
