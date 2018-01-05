# frozen_string_literal: true

module ElasticAPM
  # @api private
  module NaivelyHashable
    def naively_hashable?
      true
    end

    def to_h
      instance_variables.each_with_object({}) do |name, h|
        key = name.to_s.delete('@').to_sym
        value = instance_variable_get(name)
        is_hashable =
          value.respond_to?(:naively_hashable?) && value.naively_hashable?

        h[key] = is_hashable ? value.to_h : value
      end
    end
  end
end
