# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Context
      # @api private
      class Request
        def initialize
          @socket = {}
          @headers = {}
          @cookies = {}
          @env = {}
        end

        attr_accessor(
          :socket,
          :http_version,
          :method,
          :url,
          :headers,
          :cookies,
          :env,
          :body
        )
      end

      # @api private
      class Response
        attr_accessor(
          :status_code,
          :headers,
          :headers_sent,
          :finished
        )
      end

      attr_accessor(
        :request,
        :response,
        :user,
        :tags,
        :custom
      )
    end
  end
end
