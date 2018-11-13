# frozen_string_literal: true

require 'elastic_apm/sql_summarizer'

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SequelSpy
      TYPE = 'db.sequel.sql'

      def self.summarizer
        @summarizer ||= SqlSummarizer.new
      end

      def self.build_context(sql, opts)
        Span::Context.new(
          db: { statement: sql, type: 'sql', user: opts[:user] }
        )
      end

      # rubocop:disable Metrics/MethodLength
      def install
        require 'sequel/database/logging'

        ::Sequel::Database.class_eval do
          alias log_connection_yield_without_apm log_connection_yield

          def log_connection_yield(sql, *args, &block)
            unless ElasticAPM.current_transaction
              return log_connection_yield_without_apm(sql, *args, &block)
            end

            summarizer = ElasticAPM::Spies::SequelSpy.summarizer
            name = summarizer.summarize sql
            context = ElasticAPM::Spies::SequelSpy.build_context(sql, opts)

            ElasticAPM.with_span(name, TYPE, context: context, &block)
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    register 'Sequel', 'sequel', SequelSpy.new
  end
end
