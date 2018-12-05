# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class SpanSerializer < Serializer
        def initialize(config)
          super

          @context_serializer = ContextSerializer.new(config)
        end

        attr_reader :context_serializer

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def build(span)
          {
            span: {
              id: span.id,
              transaction_id: span.transaction_id,
              parent_id: span.parent_id,
              name: keyword_field(span.name),
              type: keyword_field(span.type),
              duration: ms(span.duration),
              context: context_serializer.build(span.context),
              stacktrace: span.stacktrace.to_a,
              timestamp: span.timestamp,
              trace_id: span.trace_id
            }
          }
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        # @api private
        class ContextSerializer < Serializer
          def build(context)
            return unless context

            {
              sync: context.sync,
              db: build_db(context.db),
              http: build_http(context.http)
            }
          end

          private

          def build_db(db)
            return unless db

            {
              instance: db.instance,
              statement: db.statement,
              type: db.type,
              user: db.user
            }
          end

          def build_http(http)
            return unless http

            {
              url: http.url,
              status_code: http.status_code.to_i,
              method: keyword_field(http.method)
            }
          end
        end
      end
    end
  end
end
