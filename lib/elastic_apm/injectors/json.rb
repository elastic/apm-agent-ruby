# frozen_string_literal: true

require 'elastic_apm/trace_helpers'

module ElasticAPM
  # @api private
  module Injectors
    # @api private
    class JSONInjector
      def install
        ::JSON.class_eval do
          include TraceHelpers
          trace_class_method :parse, 'JSON#parse', 'json.parse'
          trace_class_method :parse!, 'JSON#parse!', 'json.parse'
          trace_class_method :generate, 'JSON#generate', 'json.generate'
        end
      end
    end

    register 'JSON', 'json', JSONInjector.new
  end
end
