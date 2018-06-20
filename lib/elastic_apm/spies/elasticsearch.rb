# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class ElasticsearchSpy
      NAME_FORMAT = '%s %s'.freeze
      TYPE = 'db.elasticsearch'.freeze

      # rubocop:disable Metrics/MethodLength
      def install
        ::Elasticsearch::Transport::Client.class_eval do
          alias perform_request_without_apm perform_request

          def perform_request(method, path, *args, &block)
            name = format(NAME_FORMAT, method, path)
            statement = args[0].is_a?(String) ? args[0] : args[0].to_json
            context = Span::Context.new(statement: statement)

            ElasticAPM.span name, TYPE, context: context do
              perform_request_without_apm(method, path, *args, &block)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    register(
      'Elasticsearch::Transport::Client',
      'elasticsearch-transport',
      ElasticsearchSpy.new
    )
  end
end
