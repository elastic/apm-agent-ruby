# frozen_string_literal: true

require 'elastic_apm/context/request/url'
require 'elastic_apm/context/request/socket'
require 'elastic_apm/context/request/apply_rack_env'

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      attr_accessor :body, :cookies, :env, :headers, :http_version, :method,
        :socket, :url

      def self.from_rack_env(rack_env)
        ApplyRackEnv.call(new, rack_env)
      end
    end

    # @api private
    class Response
      def initialize(
        status_code,
        headers: {},
        headers_sent: true,
        finished: true
      )
        @status_code = status_code
        @headers = headers
        @headers_sent = headers_sent
        @finished = finished
      end

      attr_accessor :status_code, :headers, :headers_sent, :finished
    end

    attr_accessor :request, :response, :user
    attr_reader :custom, :tags

    def initialize
      @custom = {}
      @tags = {}
    end
  end
end
