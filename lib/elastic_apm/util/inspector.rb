# frozen_string_literal: true

module ElasticAPM
  module Util
    # @api private
    class Inspector
      def initialize(width = 80)
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

        transaction.spans.each do |span|
          indent = (ms(span.relative_start) * width_factor).to_i

          if span.duration
            span_width = ms(span.duration) * width_factor
            duration_desc = ms(span.duration)
          else
            span_width = width - indent
            duration_desc = 'RUNNING'
          end

          description = "[#{span.id}] " \
            "#{span.name} - #{span.type} (#{duration_desc} ms)"
          description_indent = [
            0,
            [indent, @width - description.length].min
          ].max

          lines << "#{' ' * description_indent}#{description}"
          lines << "#{' ' * indent}+#{'-' * [(span_width - 2), 0].max}+"
        end

        lines.map { |s| s[0..@width] }.join("\n")
      rescue StandardError => e
        puts e
        puts e.backspan.join("\n")
        nil
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      def ms(micros)
        micros.to_f / 1_000
      end
    end
  end
end
