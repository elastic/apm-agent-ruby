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

        def self.from_uri(uri_or_str, type: 'external')
          uri = normalize(uri_or_str)

          new(
            name: only_scheme_and_host(uri),
            resource: "#{uri.host}:#{uri.port}",
            type: type
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
