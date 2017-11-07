# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Http
    USER_AGENT = "elastic-apm/ruby #{VERSION}"
    CONTENT_TYPE = 'application/json'

    def initialize(config, adapter: HttpAdapter)
      @config = config
      @adapter = adapter.new(config)
    end

    def post(path, payload)
      data = payload.to_json

      request = @adapter.post url_for(path) do |req|
        req['Content-Type'] = CONTENT_TYPE
        req['User-Agent'] = USER_AGENT
        req['Content-Length'] = data.bytesize.to_s
        req.body = data
      end

      @adapter.perform request
    end

    private

    def url_for(path)
      "#{@config.server}#{path}"
    end
  end

  # @api private
  class HttpAdapter
    def initialize(conf)
      @config = conf
    end

    def post(path)
      req = Net::HTTP::Post.new path
      yield req if block_given?
      req
    end

    def perform(req)
      http.start do |http|
        http.request req
      end
    end

    private

    def http
      return @http if @http

      http = Net::HTTP.new server_uri.host, server_uri.port
      # http.use_ssl = @config.use_ssl
      # http.read_timeout = @config.timeout
      # http.open_timeout = @config.open_timeout

      @http = http
    end

    def server_uri
      @uri ||= URI(@config.server)
    end
  end
end
