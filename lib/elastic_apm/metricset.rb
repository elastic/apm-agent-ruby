# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Metricset
    def initialize(
      timestamp: Util.micros,
      tags: nil,
      transaction: nil,
      span: nil,
      **samples
    )
      @timestamp = timestamp
      @tags = tags
      @transaction = transaction
      @span = span
      @samples = samples
    end

    attr_accessor :timestamp, :transaction, :span, :tags
    attr_reader :samples

    def merge_tags!(tags)
      return unless tags

      @tags ||= {}
      @tags.merge! tags
    end

    def tags?
      tags&.any?
    end

    def empty?
      samples.empty?
    end

    def inspect
      "<ElasticAPM::Metricset timestamp:#{timestamp}" \
        " transaction:#{transaction.inspect}" \
        " span:#{span.inspect}" \
        " tags:#{tags.inspect}" \
        " samples:#{samples.inspect}>"
    end
  end
end
