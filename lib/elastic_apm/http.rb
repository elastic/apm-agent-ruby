# frozen_string_literal: true

require 'openssl'

require 'elastic_apm/service_info'
require 'elastic_apm/system_info'
require 'elastic_apm/process_info'
require 'elastic_apm/filters'

require_relative 'http_adapters/net_http_adapter'
require_relative 'http_adapters/http_rb_adapter'

module ElasticAPM
  # @api private
  class Http
    include Log

    USER_AGENT = "elastic-apm/ruby #{VERSION}".freeze
    ACCEPT = 'application/json'.freeze
    CONTENT_TYPE = 'application/json'.freeze

    def initialize(config)
      @config = config
      @adapter = HttpAdapters.const_get(config.http_adapter.to_sym).new(config)
      @base_payload = {
        service: ServiceInfo.build(config),
        process: ProcessInfo.build(config),
        system: SystemInfo.build(config),
      }
      @filters = Filters.new(config)
    end

    attr_reader :filters

    def post(path, payload = {})
      payload.merge! @base_payload

      payload = filters.apply(payload)
      return if payload.nil?

      response = perform path, payload.to_json
      return nil if response == ElasticAPM::HttpAdapters::AbstractHttpAdapter::DISABLED
      return response if response.success?

      error 'POST returned an unsuccessful status code (%d)', response.code
      error "apm-server's response: %s", response.body

      response
    end

    private

    def perform(path, data)
      headers = {
        'Accept' => ACCEPT,
        'Content-Type' => CONTENT_TYPE,
        'User-Agent' => USER_AGENT,
      }
      if (token = @config.secret_token)
        headers['Authorization'] = "Bearer #{token}"
      end

      @adapter.perform url_for(path), data, headers
    end

    def url_for(path)
      "#{@config.server_url}#{path}"
    end
  end
end
