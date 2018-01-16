# frozen_string_literal: true

module ElasticAPM
  class Stacktrace
    # A basic LRU Cache
    # @api private
    class LineCache
      def initialize(max_size = 512)
        @max_size = max_size
        @data = {}
      end

      class << self
        def instance
          @instance ||= new
        end
      end

      def self.get(*key)
        instance.get(*key)
      end

      def self.set(*key, value)
        instance.set(*key, value)
      end

      def get(*key)
        found = true
        value = @data.delete(key) { found = false }

        found ? @data[key] = value : nil
      end

      def set(*key, val)
        @data.delete(key)
        @data[key] = val

        return val unless @data.length > @max_size

        @data.delete(@data.first[0])

        val
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
