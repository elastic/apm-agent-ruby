# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      # @api private
      class Destination
        def initialize(
          name: nil,
          resource: nil,
          type: nil,
          address: nil,
          port: nil
        )
          @name = name
          @resource = resource
          @type = type
          @address = address
          @port = port
        end

        attr_reader(
          :name,
          :resource,
          :type,
          :address,
          :port
        )

        def self.from_uri(uri_or_str, type: 'external', port: nil)
          uri = normalize(uri_or_str)

          new(
            name: only_scheme_and_host(uri),
            resource: "#{uri.host}:#{uri.port}",
            type: type,
            address: uri.hostname,
            port: port || uri.port
          )
        end

        def self.only_scheme_and_host(uri_or_str)
          uri = normalize(uri_or_str)
          uri.path = ''
          uri.password = uri.query = uri.fragment = nil
          uri.to_s
        end

        class << self
          private

          def normalize(uri_or_str)
            return uri_or_str.dup if uri_or_str.is_a?(URI)
            URI(uri_or_str)
          end
        end
      end
    end
  end
end
