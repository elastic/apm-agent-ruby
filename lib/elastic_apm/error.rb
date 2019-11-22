# frozen_string_literal: true

require 'elastic_apm/stacktrace'
require 'elastic_apm/context'
require 'elastic_apm/error/exception'
require 'elastic_apm/error/log'

module ElasticAPM
  # @api private
  class Error
    def initialize(culprit: nil, context: nil)
      @id = SecureRandom.hex(16)
      @culprit = culprit
      @timestamp = Util.micros
      @context = context
    end

    attr_accessor :id, :culprit, :exception, :log, :transaction_id,
      :transaction, :context, :parent_id, :trace_id
    attr_reader :timestamp

    def inspect
      "<ElasticAPM::Error id:#{id}" \
        " culprit:#{culprit}" \
        " timestamp:#{timestamp}" \
        " transaction_id:#{transaction_id}" \
        " trace_id:#{trace_id}" \
        " exception:#{exception.inspect}" \
        '>'
    end
  end
end
