# frozen_string_literal: true

require 'elastic_apm/util/lru_cache'

module ElasticAPM
  # @api private
  class SqlSummarizer
    REGEXES = {
      /^SELECT .* FROM ([^ ]+)/i => 'SELECT FROM ',
      /^INSERT INTO ([^ ]+)/i => 'INSERT INTO ',
      /^UPDATE ([^ ]+)/i => 'UPDATE ',
      /^DELETE FROM ([^ ]+)/i => 'DELETE FROM '
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
        end
    end
  end
end
