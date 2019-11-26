# frozen_string_literal: true

require 'elastic_apm'
require 'opentracing'

module ElasticAPM
  module OpenTracing
    # @api private
    class Span
      def initialize(elastic_span, span_context)
        @elastic_span = elastic_span
        @span_context = span_context
      end

      attr_reader :elastic_span

      def operation_name=(name)
        elastic_span.name = name
      end

      def context
        @span_context
      end

      def set_label(key, val)
        if elastic_span.is_a?(Transaction)
          case key.to_s
          when 'type'
            elastic_span.type = val
          when 'result'
            elastic_span.result = val
          when /user\.(\w+)/
            set_user_value($1, val)
          else
            elastic_span.context.labels[key] = val
          end
        else
          elastic_span.context.labels[key] = val
        end
      end

      def set_baggage_item(_key, _value)
        ElasticAPM.agent.config.logger.warn(
          'Baggage is not supported by ElasticAPM'
        )
      end

      def get_baggage_item(_key)
        ElasticAPM.agent.config.logger.warn(
          'Baggage is not supported by ElasticAPM'
        )

        nil
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def log_kv(timestamp: nil, **fields)
        if (exception = fields[:'error.object'])
          ElasticAPM.report exception
        elsif (message = fields[:message])
          ElasticAPM.report_message message
        end
      end

      # rubocop:enable Lint/UnusedMethodArgument
      def finish(clock_end: Util.monotonic_micros, end_time: nil)
        return unless (agent = ElasticAPM.agent)

        if end_time
          warn '[ElasticAPM] DEPRECATED: Setting a custom end time as a ' \
            '`Time` is deprecated. Use `clock_end:` and monotonic time instead.'
          clock_end = end_time
        end

        elastic_span.done clock_end: clock_end

        case elastic_span
        when ElasticAPM::Transaction
          agent.instrumenter.current_transaction = nil
        when ElasticAPM::Span
          agent.instrumenter.current_spans.delete(elastic_span)
        end

        agent.enqueue elastic_span
      end

      private

      def set_user_value(key, value)
        return unless elastic_span.is_a?(Transaction)

        setter = :"#{key}="
        return unless elastic_span.context.user.respond_to?(setter)
        elastic_span.context.user.send(setter, value)
      end
    end

    # @api private
    class SpanContext
      def initialize(trace_context:, baggage: nil)
        if baggage
          ElasticAPM.agent.config.logger.warn(
            'Baggage is not supported by ElasticAPM'
          )
        end

        @trace_context = trace_context
      end

      attr_accessor :trace_context

      def self.from_trace_context(trace_context)
        new(trace_context: trace_context)
      end
    end

    # @api private
    class Scope
      def initialize(span, scope_stack, finish_on_close:)
        @span = span
        @scope_stack = scope_stack
        @finish_on_close = finish_on_close
      end

      attr_reader :span

      def elastic_span
        span.elastic_span
      end

      def close
        @span.finish if @finish_on_close
        @scope_stack.pop
      end
    end

    # @api private
    class ScopeStack
      KEY = :__elastic_apm_ot_scope_stack

      def push(scope)
        scopes << scope
      end

      def pop
        scopes.pop
      end

      def last
        scopes.last
      end

      private

      def scopes
        Thread.current[KEY] ||= []
      end
    end

    # @api private
    class ScopeManager
      def initialize
        @scope_stack = ScopeStack.new
      end

      def activate(span, finish_on_close: true)
        return active if active && active.span == span

        scope = Scope.new(span, @scope_stack, finish_on_close: finish_on_close)
        @scope_stack.push scope
        scope
      end

      def active
        @scope_stack.last
      end
    end
    # A custom tracer to use the OpenTracing API with ElasticAPM
    class Tracer
      def initialize
        @scope_manager = ScopeManager.new
      end

      attr_reader :scope_manager

      def active_span
        scope_manager.active&.span
      end

      # rubocop:disable Metrics/ParameterLists
      def start_active_span(
        operation_name,
        child_of: nil,
        references: nil,
        start_time: Time.now,
        labels: {},
        ignore_active_scope: false,
        finish_on_close: true,
        **
      )
        span = start_span(
          operation_name,
          child_of: child_of,
          references: references,
          start_time: start_time,
          labels: labels,
          ignore_active_scope: ignore_active_scope
        )
        scope = scope_manager.activate(span, finish_on_close: finish_on_close)

        if block_given?
          begin
            yield scope
          ensure
            scope.close
          end
        end

        scope
      end
      # rubocop:enable Metrics/ParameterLists

      # rubocop:disable Metrics/ParameterLists
      def start_span(
        operation_name,
        child_of: nil,
        references: nil,
        start_time: Time.now,
        labels: {},
        ignore_active_scope: false,
        **
      )
        span_context = prepare_span_context(
          child_of: child_of,
          references: references,
          ignore_active_scope: ignore_active_scope
        )

        if span_context
          trace_context =
            span_context.respond_to?(:trace_context) &&
            span_context.trace_context
        end

        elastic_span =
          if ElasticAPM.current_transaction
            ElasticAPM.start_span(
              operation_name,
              trace_context: trace_context
            )
          else
            ElasticAPM.start_transaction(
              operation_name,
              trace_context: trace_context
            )
          end

        # if no Elastic APM agent is running or transaction not sampled
        unless elastic_span
          return ::OpenTracing::Span::NOOP_INSTANCE
        end

        span_context ||=
          SpanContext.from_trace_context(elastic_span.trace_context)

        labels.each do |key, value|
          elastic_span.context.labels[key] = value
        end

        elastic_span.start Util.micros(start_time)

        Span.new(elastic_span, span_context)
      end

      # rubocop:enable Metrics/ParameterLists

      def inject(span_context, format, carrier)
        case format
        when ::OpenTracing::FORMAT_RACK
          carrier['elastic-apm-traceparent'] = span_context.to_header
        else
          warn 'Only injection via HTTP headers and Rack is available'
        end
      end

      def extract(format, carrier)
        case format
        when ::OpenTracing::FORMAT_RACK
          ElasticAPM::TraceContext
            .parse(carrier['HTTP_ELASTIC_APM_TRACEPARENT'])
        else
          warn 'Only extraction from HTTP headers via Rack is available'
          nil
        end
      rescue ElasticAPM::TraceContext::InvalidTraceparentHeader
        nil
      end

      private

      def prepare_span_context(
        child_of:,
        references:,
        ignore_active_scope:
      )
        context_from_child_of(child_of) ||
          context_from_references(references) ||
          context_from_active_scope(ignore_active_scope)
      end

      def context_from_child_of(child_of)
        return unless child_of
        child_of.respond_to?(:context) ? child_of.context : child_of
      end

      def context_from_references(references)
        return if !references || references.none?

        child_of = references.find do |reference|
          reference.type == ::OpenTracing::Reference::CHILD_OF
        end

        (child_of || references.first).context
      end

      def context_from_active_scope(ignore_active_scope)
        if ignore_active_scope
          ElasticAPM.agent&.config&.logger&.warn(
            'ignore_active_scope might lead to unexpeced results'
          )
          return
        end
        @scope_manager.active&.span&.context
      end
    end
  end
end
