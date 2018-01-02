# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Transaction
    # rubocop:disable Metrics/MethodLength
    def initialize(instrumenter, name, type = 'custom')
      @id = SecureRandom.uuid
      @instrumenter = instrumenter
      @name = name
      @type = type

      @timestamp = Util.micros

      @spans = []
      @notifications = []
      @span_id_ticker = -1

      @notifications = [] # for AS::Notifications

      @sampled = true

      yield self if block_given?
    end
    # rubocop:enable Metrics/MethodLength

    attr_accessor :id, :name, :result, :type
    attr_reader :duration, :root_span, :timestamp, :spans, :notifications,
      :sampled

    def release
      @instrumenter.current_transaction = nil
    end

    def done(result = nil)
      @result = result

      @duration = Util.micros - @timestamp

      self
    end

    def done?
      !!(@result && @duration)
    end

    def submit(result = nil)
      done result

      release

      @instrumenter.submit_transaction self

      self
    end

    def running_spans
      spans.select(&:running?)
    end

    def span(name, type = nil, context: nil)
      span = next_span(name, type, context)
      spans << span
      span.start

      return span unless block_given?

      begin
        result = yield span
      ensure
        span.done
      end

      result
    end

    def current_span
      spans.reverse.lazy.find(&:running?)
    end

    private

    def next_span_id
      @span_id_ticker += 1
    end

    def next_span(name, type, context)
      Span.new(
        self,
        next_span_id,
        name,
        type,
        parent: current_span,
        context: context
      )
    end
  end
end
