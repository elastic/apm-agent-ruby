# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      # @api private
      class Url
        include NaivelyHashable

        SKIPPED_PORTS = {
          'http' => 80,
          'https' => 443
        }.freeze

        def initialize(req)
          @protocol = req.scheme
          @hostname = req.host
          @port = req.port.to_s
          @pathname = req.path
          @search = req.query_string
          @hash = nil
          @full = build_full_url req
        end

        attr_reader :protocol, :hostname, :port, :pathname, :search, :hash,
          :full

        private

        def build_full_url(req)
          url = "#{req.scheme}://#{req.host}"

          if req.port != SKIPPED_PORTS[req.scheme]
            url += ":#{req.port}"
          end

          url + req.fullpath
        end
      end
    end
  end
end
