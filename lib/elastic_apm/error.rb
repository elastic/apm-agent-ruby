# frozen_string_literal: true

require 'elastic_apm/stacktrace'
require 'elastic_apm/context'
require 'elastic_apm/error/exception'
require 'elastic_apm/error/log'

module ElasticAPM
  # @api private
  class Error
    def initialize(culprit: nil)
      @id = SecureRandom.uuid
      @culprit = culprit

      @timestamp = Util.micros
      @context = Context.new

      @transaction_id = nil
    end

    attr_accessor :id, :culprit, :exception, :log, :transaction_id
    attr_reader :timestamp, :context
  end
end
