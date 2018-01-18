# frozen_string_literal: true

module ElasticAPM
  # @api private
  class SqlSummarizer
    REGEXES = {
      /^SELECT .* FROM ([^ ]+)/i => 'SELECT FROM ',
      /^INSERT INTO ([^ ]+)/i => 'INSERT INTO ',
      /^UPDATE ([^ ]+)/i => 'UPDATE ',
      /^DELETE FROM ([^ ]+)/i => 'DELETE FROM '
    }.freeze

    def self.cache
      @cache ||= {}
    end

    def summarize(sql)
      self.class.cache[sql] ||=
        REGEXES.find do |regex, sig|
          if (match = sql.match(regex))
            break format('%s%s'.freeze, sig, match[1].gsub(/["']/, ''))
          end
        end
    end
  end
end
