# frozen_string_literal: true

module ElasticAPM
  # @api private
  module GraphQL
    KEYS_TO_NAME = {
      'lex' => 'graphql.lex',
      'parse' => 'graphql.parse',
      'validate' => 'graphql.validate',
      'analyze_multiplex' => 'graphql.analyze_multiplex',
      'analyze_query' => 'graphql.analyze_query',
      'execute_multiplex' => 'graphql.execute_multiplex',
      'execute_query' => 'graphql.execute_query',
      'execute_query_lazy' => 'graphql.execute_query_lazy',
      # "execute_field" => "graphql.execute_field",
      # "execute_field_lazy" => "graphql.execute_field_lazy",
      # "authorized" => "graphql.authorized",
      'authorized_lazy' => 'graphql.authorized_lazy',
      'resolve_type' => 'graphql.resolve_type',
      'resolve_type_lazy' => 'graphql.resolve_type_lazy'
    }.freeze

    def self.trace(key, data)
      return yield unless KEYS_TO_NAME.key?(key)
      return yield unless (transaction = ElasticAPM.current_transaction)

      if key == 'execute_query'
        transaction.name =
          "graphql: #{data[:query].operation_name || '[unnamed]'}"
      end

      results =
        ElasticAPM.with_span(KEYS_TO_NAME.fetch(key, key), 'app.graphql') do
          yield
        end

      if key == 'execute_multiplex'
        names =
          results.map do |result|
            result.query.operation_name || '[unnamed]'
          end

        transaction.name =
          "graphql: #{names.join('+')}"
      end

      results
    end
  end
end
