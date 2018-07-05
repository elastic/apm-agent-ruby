require_relative "./abstract_adapter"

require "zlib"
require "net/http"

module ElasticAPM
  module HttpAdapters
    # @api private
    class NetHttpAdapter < AbstractHttpAdapter
      def initialize(config)
        super

        if config.http_keepalive
          $stderr.puts format(
            '%sCannot use keepalive with the Net::HTTP adapter. Use the HttpRbAdapter for keepalive.',
            Log::PREFIX
          )
        end
      end

      def perform(path, data, headers)
        return DISABLED if @config.disable_send?

        req = post(path) do |req|
          headers.each { |k, v| req[k] = v }
          prepare_request_body! req, data
        end

        resp = http.start do |http|
          http.request req
        end
        Response.new(resp)
      end

      private

      def post(path)
        req = Net::HTTP::Post.new path
        yield req if block_given?
        req
      end

      def prepare_request_body!(req, data)
        if @config.http_compression &&
           data.bytesize > @config.compression_minimum_size
          deflated = Zlib.deflate data, @config.compression_level

          req["Content-Encoding"] = "deflate"
          req["Content-Length"] = deflated.bytesize.to_s
          req.body = deflated
        else
          req["Content-Length"] = data.bytesize.to_s
          req.body = data
        end
      end

      def http
        return @http if @http

        http = Net::HTTP.new server_uri.host, server_uri.port
        http.use_ssl = @config.use_ssl?
        http.verify_mode = verify_mode
        http.read_timeout = @config.http_read_timeout
        http.open_timeout = @config.http_open_timeout

        if @config.debug_http
          http.set_debug_output(@config.logger)
        end

        @http = http
      end

      def server_uri
        @server_uri ||= URI(@config.server_url)
      end

      def verify_mode
        if @config.use_ssl? && @config.verify_server_cert?
          OpenSSL::SSL::VERIFY_PEER
        else
          OpenSSL::SSL::VERIFY_NONE
        end
      end
    end
  end
end
