# frozen_string_literal: true

require 'elastic_apm/stacktrace'
require 'elastic_apm/error/exception'
require 'elastic_apm/error/context'

module ElasticAPM
  # @api private
  class Error
    def initialize(builder, culprit)
      @builder = builder
      @culprit = culprit

      @timestamp = Util.micros
      @context = Context.new
    end

    attr_accessor :culprit, :exception
    attr_reader :timestamp, :context
  end
end
