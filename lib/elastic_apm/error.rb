# frozen_string_literal: true

require 'elastic_apm/stacktrace'
require 'elastic_apm/context'
require 'elastic_apm/error/exception'
require 'elastic_apm/error/log'

module ElasticAPM
  # @api private
  class Error
    def initialize(culprit: nil)
      @id = SecureRandom.hex(16)
      @trace_id = nil
      @culprit = culprit

      @timestamp = Util.micros
      @context = Context.new

      @transaction_id = nil
      @parent_id = nil
    end

    attr_accessor :id, :culprit, :exception, :log, :transaction_id, :context,
      :parent_id, :trace_id
    attr_reader :timestamp
  end
end
