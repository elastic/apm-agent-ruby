# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      # @api private
      class Socket
        def initialize(req)
          @remote_addr = req.env['REMOTE_ADDR']
          @encrypted = req.scheme == 'https'
        end

        attr_reader :remote_addr, :encrypted
      end
    end
  end
end
