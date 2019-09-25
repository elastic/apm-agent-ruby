# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metricset
    def initialize(timestamp: Util.micros, labels: nil, **samples)
      @timestamp = timestamp
      @labels = labels
      @samples = samples
    end

    attr_accessor :timestamp
    attr_reader :samples, :labels

    def empty?
      samples.empty?
    end
  end
end
