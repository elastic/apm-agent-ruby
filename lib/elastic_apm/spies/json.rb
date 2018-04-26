# frozen_string_literal: true

require 'elastic_apm/span_helpers'

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class JSONSpy
      def install
        ::JSON.class_eval do
          include SpanHelpers
          span_class_method :parse, 'JSON#parse', 'json.parse'
          span_class_method :parse!, 'JSON#parse!', 'json.parse'
          span_class_method :generate, 'JSON#generate', 'json.generate'
        end
      end
    end

    register 'JSON', 'json', JSONSpy.new
  end
end
