# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class WildcardPatternList
      # @api private
      class WildcardPattern
        def initialize(str)
          @pattern = convert(str)
        end

        def match?(other)
          !!@pattern.match(other)
        end

        alias :match :match?

        private

        def convert(str)
          parts =
            str.chars.each_with_object([]) do |char, arr|
              arr << (char == '*' ? '.*' : Regexp.escape(char))
            end

          Regexp.new('\A' + parts.join + '\Z', Regexp::IGNORECASE)
        end
      end

      def call(value)
        value = value.is_a?(String) ? value.split(',') : Array(value)
        value.map(&WildcardPattern.method(:new))
      end
    end
  end
end
