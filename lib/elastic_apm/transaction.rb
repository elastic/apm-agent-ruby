# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Transaction
    ROOT_TRACE_NAME = 'transaction'

    def initialize(agent, name, type = 'custom', result = nil)
      @agent = agent
      @name = name
      @type = type
      @result = result

      @timestamp = Util.nearest_minute.to_i

      @root_trace = Trace.new(self, ROOT_TRACE_NAME, ROOT_TRACE_NAME)
      @traces = [@root_trace]
      @notifications = []

      @start_time = Util.nanos
      @root_trace.start @start_time
    end

    attr_accessor :name, :result, :type
    attr_reader :duration, :root_trace, :start_time, :timestamp, :traces

    def release
      @agent.current_transaction = nil
    end

    def done(result = nil)
      @result = result

      @root_trace.done Util.nanos
      @duration = @root_trace.duration

      self
    end

    def done?
      @root_trace.done?
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

    # rubocop:disable Metrics/MethodLength
    def trace(name, type = nil, extra = nil)
      trace = Trace.new self, name, type, running_traces, extra

      relative_time = current_offset

      traces << trace

      trace.start relative_time

      return trace unless block_given?

      begin
        result = yield trace
      ensure
        trace.done
      end

      result
    end
    # rubocop:enable Metrics/MethodLength

    private

    def current_trace
      traces.reverse.find(&:running?)
    end

    def current_offset
      if (curr = current_trace)
        return curr.start_time
      end

      start_time
    end
  end
end
