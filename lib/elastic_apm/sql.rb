# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Sql
    # This method is only here as a shortcut while the agent ships with
    # both implementations ~mikker
    def self.summarizer
      @summarizer ||=
        if ElasticAPM.agent&.config&.use_experimental_sql_parsing
          require 'elastic_apm/sql/signature'
          Sql::Signature::Summarizer.new
        else
          SqlSummarizer.new
        end
    end
  end
end
