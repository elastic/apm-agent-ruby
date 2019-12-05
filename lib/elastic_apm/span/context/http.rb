# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      # @api private
      class Http
        def initialize(url: nil, status_code: nil, method: nil)
          @url = Util.sanitize_url(url)
          @status_code = status_code
          @method = method
        end

        attr_accessor :url, :status_code, :method
      end
    end
  end
end
