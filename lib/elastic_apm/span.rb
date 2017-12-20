# frozen_string_literal: true

require 'elastic_apm/span/context'

module ElasticAPM
  # @api private
  class Span
    DEFAULT_KIND = 'custom'.freeze

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      transaction,
      id,
      name,
      type = DEFAULT_KIND,
      parent: nil,
      context: nil
    )
      @transaction = transaction
      @id = id
      @name = name
      @type = type
      @parent = parent
      @context = context
    end
    # rubocop:enable Metrics/ParameterLists

    attr_accessor :name, :context, :type
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
  end
end
