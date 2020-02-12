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
          # rubocop:disable Metrics/CyclomaticComplexity
          def build(context)
            return unless context

            base = {}

            base[:tags] = mixed_object(context.labels) if context.labels.any?
            base[:sync] = context.sync unless context.sync.nil?
            base[:db] = build_db(context.db) if context.db
            base[:http] = build_http(context.http) if context.http

            if context.destination
              base[:destination] = build_destination(context.destination)
            end

            base
          end
          # rubocop:enable Metrics/CyclomaticComplexity

          private

          def build_db(db)
            {
              instance: db.instance,
              statement: Util.truncate(db.statement, max_length: 10_000),
              type: db.type,
              user: db.user,
              rows_affected: db.rows_affected
            }
          end

          def build_http(http)
            {
              url: http.url,
              status_code: http.status_code.to_i,
              method: keyword_field(http.method)
            }
          end

          def build_destination(destination)
            {
              service: {
                name: keyword_field(destination.name),
                resource: keyword_field(destination.resource),
                type: keyword_field(destination.type)
              }
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
