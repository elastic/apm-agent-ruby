# frozen_string_literal: true

require 'elastic_apm/stacktrace'
require 'elastic_apm/error/exception'
require 'elastic_apm/error/log'
require 'elastic_apm/error/context'

module ElasticAPM
  # @api private
  class Error
    def initialize(culprit: nil)
      @id = SecureRandom.uuid
      @culprit = culprit

      @timestamp = Util.micros
      @context = Context.new
    end

    attr_accessor :id, :culprit, :exception, :log
    attr_reader :timestamp, :context
  end
end
