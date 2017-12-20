# frozen_string_literal: true

require 'elastic_apm/sql_summarizer'

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class SequelInjector
      TYPE = 'db.sequel.sql'.freeze

      def self.summarizer
        @summarizer ||= SqlSummarizer.new
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

            summarizer = ElasticAPM::Injectors::SequelInjector.summarizer
            name = summarizer.summarize sql
            context = Span::Context.new(
              statement: sql,
              type: 'sql',
              user: opts[:user]
            )

            ElasticAPM.span(name, TYPE, context: context, &block)
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    register 'Sequel', 'sequel', SequelInjector.new
  end
end
