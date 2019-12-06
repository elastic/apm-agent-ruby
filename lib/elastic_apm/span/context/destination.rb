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

        def self.from_uri(uri)
          new(
            name: Util.sanitize_url(uri),
            resource: "#{uri.host}:#{uri.port}",
            type: 'external'
          )
        end
      end
    end
  end
end
