# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      # @api private
      class Url
        SKIPPED_PORTS = {
          'http' => 80,
          'https' => 443
        }.freeze

        def initialize(req)
          @protocol = req.scheme
          @hostname = req.host
          @port = req.port
          @pathname = req.path
          @search = req.query_string
          @hash = nil
          @full = build_full_url req
        end

        attr_reader :protocol, :hostname, :port, :pathname, :search, :hash,
          :full

        def to_h
          %i[
            protocol hostname port pathname search hash full
          ].each_with_object({}) do |key, h|
            h[key] = send(key)
          end
        end

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
