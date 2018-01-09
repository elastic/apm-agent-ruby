# frozen_string_literal: true

module ElasticAPM
  class Context
    # @api private
    class Request
      include NaivelyHashable

      attr_accessor :body, :cookies, :env, :headers, :http_version, :method,
        :socket, :url
    end
  end
end
