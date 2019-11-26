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
        def build(span)
          {
            span: {
              id: span.id,
              transaction_id: span.transaction.id,
              parent_id: span.parent_id,
              name: keyword_field(span.name),
              type: join_type(span),
              duration: ms(span.duration),
              context: context_serializer.build(span.context),
              stacktrace: span.stacktrace.to_a,
              timestamp: span.timestamp,
              trace_id: span.trace_id
            }
          }
        end

        # @api private
        class ContextSerializer < Serializer
          def build(context)
            return unless context

            { sync: context.sync }.tap do |base|
              base[:db] = build_db(context.db) if context.db
              base[:http] = build_http(context.http) if context.http
            end
          end

          private

          def build_db(db)
            return unless db

            {
              instance: db.instance,
              statement: Util.truncate(db.statement, max_length: 10_000),
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

        private

        def join_type(span)
          combined = [span.type, span.subtype, span.action]
          combined.compact!
          combined.join '.'
        end
      end
    end
  end
end
