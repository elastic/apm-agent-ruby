# frozen_string_literal: true

require 'elastic_apm/span/context'

module ElasticAPM
  # @api private
  class Span
    DEFAULT_TYPE = 'custom'.freeze

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      transaction,
      id,
      name,
      type = nil,
      parent: nil,
      context: nil
    )
      @transaction = transaction
      @id = id
      @name = name
      @type = type || DEFAULT_TYPE
      @parent = parent
      @context = context
      @stacktrace = nil
    end
    # rubocop:enable Metrics/ParameterLists

    attr_accessor :name, :context, :type, :stacktrace
    attr_reader :id, :duration, :parent, :relative_start

    def start
      @relative_start = Util.micros - @transaction.timestamp

      self
    end

    def done
      @duration = Util.micros - @transaction.timestamp - relative_start

      self
    end

    def done?
      !!duration
    end

    def running?
      relative_start && !done?
    end

    def inspect
      "<ElasticAPM::Span id:#{id}" \
        " name:#{name.inspect}" \
        " type:#{type.inspect}" \
        '>'
    end
  end
end
