# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class GraphQLSpy
      def install
      end
    end

    register(
      'GraphQL',
      'graphql',
      GraphQLSpy.new
    )
  end
end
