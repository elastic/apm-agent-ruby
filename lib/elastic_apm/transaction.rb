# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Transaction
    def initialize(agent, name, type = 'custom', result = nil)
      @agent = agent
      @name = name
      @type = type
      @result = result

      @timestamp = Util.micros

      @traces = []
      @notifications = []
      @trace_id_ticker = -1

      yield self if block_given?
    end

    attr_accessor :name, :result, :type
    attr_reader :duration, :root_trace, :timestamp, :traces

    def release
      @agent.current_transaction = nil
    end

    def done(result = nil)
      @result = result

      @duration = Util.micros - @timestamp

      self
    end

    def done?
      !!@result
    end

    def submit(result = nil)
      done result

      release

      @agent.submit_transaction self

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

    private

    def next_trace_id
      @trace_id_ticker += 1
    end

    def current_trace
      traces.reverse.lazy.find(&:running?)
    end
  end
end
