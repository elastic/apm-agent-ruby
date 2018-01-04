# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      # @api private
      class Socket
        def initialize(req)
          @remote_addr = req.ip
          @encrypted = req.scheme == 'https'
        end

        attr_reader :remote_addr, :encrypted

        def to_h
          %i[remote_addr encrypted].each_with_object({}) do |key, h|
            h[key] = send(key)
          end
        end
      end
    end
  end
end
