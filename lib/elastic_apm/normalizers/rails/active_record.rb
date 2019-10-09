# frozen_string_literal: true

require 'elastic_apm/sql_summarizer'

module ElasticAPM
  module Normalizers
    module ActiveRecord
      # @api private
      class SqlNormalizer < Normalizer
        register 'sql.active_record'

        TYPE = 'db'
        ACTION = 'sql'

        def initialize(*args)
          super

          @subtype = lookup_adapter || 'unknown'
          @summarizer = SqlSummarizer.new
        end

        def normalize(_transaction, _name, payload)
          return :skip if %w[SCHEMA CACHE].include?(payload[:name])

          name = summarize(payload[:sql]) || payload[:name]
          context =
            Span::Context.new(db: { statement: payload[:sql], type: 'sql' })
          [name, TYPE, @subtype, ACTION, context]
        end

        private

        def summarize(sql)
          @summarizer.summarize(sql)
        end

        def lookup_adapter
          ::ActiveRecord::Base.connection.adapter_name.downcase
        rescue StandardError
          nil
        end
      end
    end
  end
end
