# frozen_string_literal: true

module ElasticAPM
  class CentralConfig
    # @api private
    class CacheControl
      def initialize(value)
        @header = value
        parse!(value)
      end

      attr_reader(
        :must_revalidate,
        :no_cache,
        :no_store,
        :no_transform,
        :public,
        :private,
        :proxy_revalidate,
        :max_age,
        :s_maxage
      )

      private

      def parse!(value)
        value.split(',').each do |token|
          k, v = token.split('=').map(&:strip)
          instance_variable_set(:"@#{k.tr('-', '_')}", v ? v.to_i : true)
        end
      end
    end
  end
end
