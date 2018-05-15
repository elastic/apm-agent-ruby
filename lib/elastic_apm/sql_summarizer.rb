# frozen_string_literal: true

require 'elastic_apm/util/lru_cache'

module ElasticAPM
  # @api private
  class SqlSummarizer
    DEFAULT = 'SQL'.freeze
    TABLE_REGEX = %{["'`]?([A-Za-z0-9]+)}.freeze

    REGEXES = {
      /^BEGIN/i => 'BEGIN',
      /^COMMIT/i => 'COMMIT',
      /^SELECT .* FROM #{TABLE_REGEX}/i => 'SELECT FROM ',
      /^INSERT INTO #{TABLE_REGEX}/i => 'INSERT INTO ',
      /^UPDATE #{TABLE_REGEX}/i => 'UPDATE ',
      /^DELETE FROM #{TABLE_REGEX}/i => 'DELETE FROM '
    }.freeze

    FORMAT = '%s%s'.freeze

    def self.cache
      @cache ||= Util::LruCache.new
    end

    def summarize(sql)
      self.class.cache[sql] ||=
        REGEXES.find do |regex, sig|
          if (match = sql.match(regex))
            break format(FORMAT, sig, match[1].gsub(/["']/, ''))
          end
        end || DEFAULT
    end
  end
end
