# frozen_string_literal: true

module ElasticAPM
  module Util
    # @api private
    class LruCache
      def initialize(max_size = 512)
        @max_size = max_size
        @data = {}
      end

      def [](key)
        found = true
        value = @data.delete(key) { found = false }

        found ? @data[key] = value : nil
      end

      def []=(key, val)
        @data.delete(key)
        @data[key] = val

        return unless @data.length > @max_size

        @data.delete(@data.first[0])
      end

      def length
        @data.length
      end

      def to_a
        @data.to_a
      end
    end
  end
end
