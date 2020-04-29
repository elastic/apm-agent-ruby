# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

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

    def self.cache
      @cache ||= Util::LruCache.new
    end

    def summarize(sql)
      sql = sql.encode('utf-8', invalid: :replace, undef: :replace)
      self.class.cache[sql] ||=
        REGEXES.find do |regex, sig|
          if (match = sql[0...1000].match(regex))
            break format(FORMAT, sig, match[1] && match[1].gsub(/["']/, ''))
          end
        end || DEFAULT
    end
  end
end
