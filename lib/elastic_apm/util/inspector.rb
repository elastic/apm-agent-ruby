# frozen_string_literal: true

module ElasticAPM
  module Util
    # @api private
    class Inspector
      include Log

      def initialize(width = 110)
        @width = width
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def transaction(transaction)
        unless transaction.done?
          raise ArgumentError, 'Transaction still running'
        end

        width_factor = @width.to_f / ms(transaction.duration)

        lines = ['=' * @width]
        lines << "[T] #{transaction.name} " \
          "- #{transaction.type} (#{ms transaction.duration} ms)"
        lines << "+#{'-' * (@width - 2)}+"

        transaction.traces.each do |trace|
          indent = (ms(trace.relative_start) * width_factor).to_i
          trace_width = ms(trace.duration) * width_factor

          description = "[#{trace.id}] " \
            "#{trace.name} - #{trace.type} (#{ms trace.duration} ms)"
          description_indent = [indent, @width - description.length].min

          lines << "#{' ' * description_indent}#{description}"
          lines << "#{' ' * indent}+#{'-' * [(trace_width - 2), 0].max}+"
        end

        lines.map { |s| s[0..@width] }.join("\n")
      rescue StandardError => e
        debug e
        debug e.backtrace.join("\n")
        transaction.inspect
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      def ms(micros)
        micros / 1_000
      end
    end
  end
end
