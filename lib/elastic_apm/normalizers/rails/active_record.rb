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
        SKIP_NAMES = %w[SCHEMA CACHE].freeze

        def initialize(*args)
          super

          @summarizer = SqlSummarizer.new
        end

        def normalize(_transaction, _name, payload)
          return :skip if SKIP_NAMES.include?(payload[:name])

          name = summarize(payload[:sql]) || payload[:name]
          context =
            Span::Context.new(db: { statement: payload[:sql], type: 'sql' })
          [name, TYPE, subtype(payload), ACTION, context]
        end

        private

        def subtype(payload)
          @subtype ||= (lookup_adapter(payload) || 'unknown')
        end

        def summarize(sql)
          @summarizer.summarize(sql)
        end

        def lookup_adapter(payload)
          connection = payload[:connection] || ::ActiveRecord::Base.connection
          connection.adapter_name.downcase
        rescue StandardError
          nil
        end
      end
    end
  end
end
