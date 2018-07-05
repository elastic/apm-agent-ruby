require_relative "./abstract_adapter"

begin
  require "http"
rescue LoadError
end

module ElasticAPM
  module HttpAdapters
    # @api private
    class HttpRbAdapter < AbstractHttpAdapter
      def perform(uri, data, headers)
        return DISABLED if @config.disable_send?

        ctx = OpenSSL::SSL::SSLContext.new
        if @config.use_ssl? && @config.verify_server_cert?
          ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        req = client(uri).headers(headers)
        if @config.http_compression && data.bytesize > @config.compression_minimum_size
          req = req.use(auto_deflate: {method: :deflate})
        end
        Response.new req.post(uri, body: data, ssl_context: ctx)
      end

      private

      def client(uri)
        if @config.http_keepalive
          @client ||= ::HTTP.persistent(uri)
        else
          @client ||= ::HTTP
        end
      end
    end
  end
end if Kernel.const_defined?(:HTTP) && ::HTTP.const_defined?(:Chainable)
