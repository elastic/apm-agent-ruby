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
        UNKNOWN = 'unknown'

        def initialize(*args)
          super

          @summarizer = SqlSummarizer.new
          @adapters = {}
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
          connection_adapter(
            payload[:connection] || ::ActiveRecord::Base.connection
          )
        end

        def summarize(sql)
          @summarizer.summarize(sql)
        end

        def connection_adapter(conn)
          return UNKNOWN unless conn.adapter_name
          @adapters[conn.adapter_name] ||
            (@adapters[conn.adapter_name] = conn.adapter_name.downcase)
        rescue StandardError
          nil
        end
      end
    end
  end
end
