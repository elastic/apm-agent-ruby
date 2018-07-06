require_relative './abstract_adapter'
begin
  require 'http'
rescue LoadError
end

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
        @client ||= @config.http_keepalive ? ::HTTP.persistent(uri) : ::HTTP
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
end if Kernel.const_defined?(:HTTP) && ::HTTP.const_defined?(:Chainable)
