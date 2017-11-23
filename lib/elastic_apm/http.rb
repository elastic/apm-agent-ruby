# frozen_string_literal: true

require 'net/http'

module ElasticAPM
  # @api private
  class Http
    include Log

    USER_AGENT = "elastic-apm/ruby #{VERSION}"
    CONTENT_TYPE = 'application/json'

    def initialize(config, adapter: HttpAdapter)
      @config = config
      @adapter = adapter.new(config)
      @app_info = build_app_info(config)
    end

    attr_reader :config

    def post(path, payload = {})
      data = payload.merge(@app_info).to_json

      request = prepare_request path, data
      response = @adapter.perform request

      status = response.code.to_i
      return response if status >= 200 && status <= 299

      error "POST returned an unsuccessful status code (#{response.code})"
      debug response.body
    end

    private

    def prepare_request(path, data)
      @adapter.post url_for(path) do |req|
        req['Content-Type'] = CONTENT_TYPE
        req['User-Agent'] = USER_AGENT
        req['Content-Length'] = data.bytesize.to_s

        if (token = config.secret_token)
          req['Authorization'] = "Bearer #{token}"
        end

        req.body = data
      end
    end

    def build_app_info(config)
      {
        app: {
          name: config.app_name,
          agent: {
            name: 'ruby',
            version: VERSION
          }
        }
      }
    end

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
      http.use_ssl = @config.use_ssl?
      http.read_timeout = @config.timeout
      http.open_timeout = @config.open_timeout

      @http = http
    end

    def server_uri
      @uri ||= URI(@config.server)
    end
  end
end
