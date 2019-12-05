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

        def sanitize_url(url)
          uri = URI(url)

          return url unless uri.userinfo

          format(
            '%s://%s@%s%s',
            uri.scheme,
            uri.user,
            uri.hostname,
            uri.path
          )
        end
      end
    end
  end
end
