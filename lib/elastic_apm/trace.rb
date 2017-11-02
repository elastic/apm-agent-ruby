# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Trace
    DEFAULT_KIND = 'custom'

    def initialize(
      transaction,
      name,
      type = DEFAULT_KIND,
      parents = [],
      extra = nil
    )
      @transaction = transaction
      @name = name
      @type = type
      @parents = parents
      @extra = extra

      @timestamp = Util.nearest_minute.to_i
    end

    attr_accessor :name, :extra, :type
    attr_reader :duration, :parents, :relative_start, :start_time, :timestamp

    def start(relative_to)
      @start_time = Util.nanos
      @relative_start = start_time - relative_to

      self
    end

    def done(nanos = Util.nanos)
      @duration = nanos - start_time

      self
    end

    def done?
      !!duration
    end

    def running?
      start_time && !done?
    end
  end
end
