# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metricset
    def initialize(timestamp: Util.micros, tags: nil, **samples)
      @timestamp = timestamp
      @tags = tags
      @samples = samples
    end

    attr_accessor :timestamp
    attr_reader :samples, :tags

    def empty?
      samples.empty?
    end
  end
end
