# frozen_string_literal: true

require 'elastic_apm/sql_summarizer'

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class SequelInjector
      TYPE = 'db.sequel.sql'

      def self.summarizer
        @summarizer ||= SqlSummarizer.new
      end

      def install
        require 'sequel/database/logging'

        log_method =
          if ::Sequel::Database.method_defined?(:log_connection_yield)
            'log_connection_yield'
          else
            'log_yield'
          end

        ::Sequel::Database.class_eval <<-RUBY
          alias #{log_method}_without_apm #{log_method}

          def #{log_method}(sql, *args, &block)
            unless ElasticAPM.current_transaction
              return #{log_method}_without_apm(sql, *args, &block)
            end

            #{log_method}_without_apm(sql, *args) do
              summarizer = ElasticAPM::Injectors::SequelInjector.summarizer
              name = summarizer.summarize sql

              ElasticAPM.span(name, TYPE, sql: sql, &block)
            end
          end
        RUBY
      end
    end

    register 'Sequel', 'sequel', SequelInjector.new
  end
end
