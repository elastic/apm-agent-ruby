# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Transaction
    def initialize(instrumenter, name, type = 'custom', result = nil)
      @instrumenter = instrumenter
      @name = name
      @type = type
      @result = result

      @timestamp = Util.micros

      @traces = []
      @notifications = []
      @trace_id_ticker = -1

      @notifications = [] # for AS::Notifications

      yield self if block_given?
    end

    attr_accessor :name, :result, :type
    attr_reader :duration, :root_trace, :timestamp, :traces, :notifications

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

    def running_traces
      traces.select(&:running?)
    end

    def trace(name, type = nil, extra = nil)
      trace = Trace.new self, next_trace_id, name, type, current_trace, extra
      traces << trace
      trace.start

      return trace unless block_given?

      begin
        result = yield trace
      ensure
        trace.done
      end

      result
    end

    def current_trace
      traces.reverse.lazy.find(&:running?)
    end

    private

    def next_trace_id
      @trace_id_ticker += 1
    end
  end
end
