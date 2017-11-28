# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Span
    DEFAULT_KIND = 'custom'

    # rubocop:disable Metrics/ParameterLists
    def initialize(
      transaction,
      id,
      name,
      type = DEFAULT_KIND,
      parent = nil,
      extra = nil
    )
      @transaction = transaction
      @id = id
      @name = name
      @type = type
      @parent = parent
      @extra = extra
    end
    # rubocop:enable Metrics/ParameterLists

    attr_accessor :name, :extra, :type
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
