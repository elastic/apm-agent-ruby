# frozen_string_literal: true

module ElasticAPM
  class Config
    # @api private
    class RegexpList
      def call(value)
        value = value.is_a?(String) ? value.split(',') : Array(value)
        value.map(&Regexp.method(:new))
      end
    end
  end
end
