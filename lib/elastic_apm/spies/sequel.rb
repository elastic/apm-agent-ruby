# frozen_string_literal: true

require 'elastic_apm/sql'

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SequelSpy
      TYPE = 'db'
      ACTION = 'query'

      def self.summarizer
        @summarizer = Sql.summarizer
      end

      def install
        require 'sequel/database/logging'

        ::Sequel::Database.class_eval do
          alias log_connection_yield_without_apm log_connection_yield

          def log_connection_yield(sql, connection, args = nil, &block)
            unless ElasticAPM.current_transaction
              return log_connection_yield_without_apm(
                sql, connection, args, &block
              )
            end

            subtype = database_type.to_s

            name =
              ElasticAPM::Spies::SequelSpy.summarizer.summarize sql

            context = ElasticAPM::Span::Context.new(
              db: { statement: sql, type: 'sql', user: opts[:user] },
              destination: { name: subtype, resource: subtype, type: TYPE }
            )

            span = ElasticAPM.start_span(
              name,
              TYPE,
              subtype: subtype,
              action: ACTION,
              context: context
            )
            yield.tap do |result|
              if name =~ /^(UPDATE|DELETE)/
                if connection.respond_to?(:changes)
                  span.context.db.rows_affected = connection.changes
                elsif result.is_a?(Integer)
                  span.context.db.rows_affected = result
                end
              end
            end
          ensure
            ElasticAPM.end_span
          end
        end
      end
    end

    register 'Sequel', 'sequel', SequelSpy.new
  end
end
