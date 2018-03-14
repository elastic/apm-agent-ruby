# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class ElasticsearchInjector
      NAME_FORMAT = '%s %s'.freeze
      TYPE = 'db.elasticsearch'.freeze

      def install
        ::Elasticsearch::Transport::Client.class_eval do
          alias perform_request_without_apm perform_request

          def perform_request(method, path, params = {}, body = nil)
            name = format(NAME_FORMAT, method, path)
            context = Span::Context.new(statement: params)

            ElasticAPM.span name, TYPE, context: context do
              perform_request_without_apm(method, path, params, body)
            end
          end
        end
      end
    end

    register(
      'Elasticsearch::Transport::Client',
      'elasticsearch-transport',
      ElasticsearchInjector.new
    )
  end
end
