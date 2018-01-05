# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      # @api private
      class Socket
        include NaivelyHashable

        def initialize(req)
          @remote_addr = req.ip
          @encrypted = req.scheme == 'https'
        end

        attr_reader :remote_addr, :encrypted
      end
    end
  end
end
