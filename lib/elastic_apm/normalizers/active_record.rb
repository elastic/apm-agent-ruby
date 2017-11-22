# frozen_string_literal: true

require 'elastic_apm/sql_summarizer'

module ElasticAPM
  module Normalizers
    module ActiveRecord
      # @api private
      class SqlNormalizer < Normalizer
        register 'sql.active_record'

        def initialize(*args)
          super(*args)

          @type = format('db.%s.sql', lookup_adapter || 'unknown')
          @summarizer = SqlSummarizer.new
        end

        def normalize(_transaction, _name, payload)
          return :skip if %w[SCHEMA CACHE].include?(payload[:name])

          name = summarize(payload[:sql]) || payload[:name] || 'SQL'
          [name, @type, { sql: payload[:sql] }]
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
