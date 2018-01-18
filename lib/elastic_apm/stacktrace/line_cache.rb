# frozen_string_literal: true

require 'elastic_apm/util/lru_cache'

module ElasticAPM
  class Stacktrace
    # A basic LRU Cache
    # @api private
    class LineCache
      class << self
        def cache
          @cache ||= Util::LruCache.new
        end

        def get(*key)
          cache[key]
        end

        def set(*key, value)
          cache[key] = value
        end
      end
    end
  end
end
