# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      # @api private
      class Destination
        def initialize(name: nil, resource: nil, type: nil)
          @name = name
          @resource = resource
          @type = type
        end

        attr_reader :name, :resource, :type

        def self.from_uri(uri, type: 'external')
          new(
            name: only_scheme_and_host(uri),
            resource: "#{uri.host}:#{uri.port}",
            type: type
          )
        end

        def self.only_scheme_and_host(uri_or_str)
          uri = uri_or_str.is_a?(URI) ? uri_or_str.dup : URI(uri_or_str)
          uri.path = ''
          uri.password = uri.query = uri.fragment = nil
          uri.to_s
        end
      end
    end
  end
end
