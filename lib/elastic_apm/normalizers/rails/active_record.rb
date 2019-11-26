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
          cached_adapter_name(
            payload[:connection]&.adapter_name ||
              ::ActiveRecord::Base.connection_config[:adapter]
          )
        end

        def summarize(sql)
          @summarizer.summarize(sql)
        end

        def cached_adapter_name(adapter_name)
          return UNKNOWN if adapter_name.nil? || adapter_name.empty?
          @adapters[adapter_name] ||
            (@adapters[adapter_name] = adapter_name.downcase)
        rescue StandardError
          nil
        end
      end
    end
  end
end
