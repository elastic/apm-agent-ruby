# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metricset
    def initialize(timestamp: Util.micros, **samples)
      @timestamp = timestamp
      @samples = samples
    end

    attr_accessor :timestamp
    attr_reader :samples

    def empty?
      samples.empty?
    end
  end
end
