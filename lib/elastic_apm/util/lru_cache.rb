# frozen_string_literal: true

module ElasticAPM
  module Util
    # @api private
    class LruCache
      def initialize(max_size = 512, &block)
        @max_size = max_size
        @data = Hash.new(&block)
        @mutex = Mutex.new
      end

      def [](key)
        @mutex.synchronize do
          val = @data[key]
          return unless val
          add(key, val)
          val
        end
      end

      def []=(key, val)
        @mutex.synchronize do
          add(key, val)
        end
      end

      def length
        @data.length
      end

      def to_a
        @data.to_a
      end

      private

      def add(key, val)
        @data.delete(key)
        @data[key] = val

        return unless @data.length > @max_size

        @data.delete(@data.first[0])
      end
    end
  end
end
