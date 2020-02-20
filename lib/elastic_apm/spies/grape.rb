# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class GrapeSpy
      def install
        require 'elastic_apm/grape'
      end
    end

    register 'Grape', 'grape', GrapeSpy.new
  end
end
