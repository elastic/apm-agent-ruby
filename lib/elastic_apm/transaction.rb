# frozen_string_literal: true

require 'elastic_apm/context'

module ElasticAPM
  # @api private
  class Transaction
    # rubocop:disable Metrics/MethodLength
    def initialize(instrumenter, name, type = 'custom', rack_env: nil)
      @id = SecureRandom.uuid
      @instrumenter = instrumenter
      @name = name
      @type = type

      @timestamp = Util.micros

      @spans = []
      @notifications = []
      @span_id_ticker = -1

      @notifications = [] # for AS::Notifications

      @context = Context.new

      if rack_env
        @context.request = Context::Request.from_rack_env rack_env
      end

      @sampled = true

      yield self if block_given?
    end
    # rubocop:enable Metrics/MethodLength

    attr_accessor :id, :name, :result, :type
    attr_reader :context, :duration, :root_span, :timestamp, :spans,
      :notifications, :sampled

    def release
      @instrumenter.current_transaction = nil
    end

    def done(result = nil)
      @duration = Util.micros - @timestamp
      @result = result

      self
    end

    def done?
      !!(@result && @duration)
    end

    def submit(status = nil, headers: {})
      done status

      context.response = Context::Response.new(status, headers: headers)

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

    def inspect
      "<ElasticAPM::Transaction id:#{id}>"
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
