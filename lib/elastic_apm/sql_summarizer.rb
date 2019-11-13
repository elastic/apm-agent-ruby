# frozen_string_literal: true

require 'elastic_apm/util/lru_cache'

module ElasticAPM
  # @api private
  class SqlSummarizer
    DEFAULT = 'SQL'
    TABLE_REGEX = %{["'`]?([A-Za-z0-9_]+)["'`]?}

    REGEXES = {
      /^BEGIN/iu => 'BEGIN',
      /^COMMIT/iu => 'COMMIT',
      /^SELECT .* FROM #{TABLE_REGEX}/iu => 'SELECT FROM ',
      /^INSERT INTO #{TABLE_REGEX}/iu => 'INSERT INTO ',
      /^UPDATE #{TABLE_REGEX}/iu => 'UPDATE ',
      /^DELETE FROM #{TABLE_REGEX}/iu => 'DELETE FROM '
    }.freeze

    FORMAT = '%s%s'
    UTF8 = 'UTF-8'

    def self.cache
      @cache ||= Util::LruCache.new
    end

    def summarize(sql)
      sql = sql.encode(UTF8, invalid: :replace, undef: :replace)
      self.class.cache[sql] ||=
        REGEXES.find do |regex, sig|
          if (match = sql[0...1000].match(regex))
            break format(FORMAT, sig, match[1] && match[1].gsub(/["']/, ''))
          end
        end || DEFAULT
    end
  end
end
