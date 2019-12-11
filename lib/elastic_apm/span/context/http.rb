# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      # @api private
      class Http
        def initialize(url: nil, status_code: nil, method: nil)
          @url = sanitize_url(url)
          @status_code = status_code
          @method = method
        end

        attr_accessor :url, :status_code, :method

        private

        def sanitize_url(uri_or_str)
          uri = uri_or_str.is_a?(URI) ? uri_or_str.dup : URI(uri_or_str)
          uri.password = nil
          uri.to_s
        end
      end
    end
  end
end
