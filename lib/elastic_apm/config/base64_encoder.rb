# frozen_string_literal: true

require 'base64'

module ElasticAPM
  class Config
    # @api private
    class Base64Encoder
      def call(value)
        Base64.strict_encode64(value)
      end
    end
  end
end
