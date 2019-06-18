# frozen_string_literal: true

require 'elastic_apm/naively_hashable'

module ElasticAPM
  class Stacktrace
    # @api private
    class Frame
      include NaivelyHashable

      attr_accessor(
        :abs_path,
        :filename,
        :function,
        :vars,
        :pre_context,
        :context_line,
        :post_context,
        :library_frame,
        :lineno,
        :module,
        :colno
      )

      # rubocop:disable Metrics/AbcSize
      def build_context(context_line_count)
        return unless abs_path && context_line_count > 0

        padding = (context_line_count - 1) / 2
        from = lineno - padding - 1
        from = 0 if from < 0
        to = lineno + padding - 1
        file_lines = read_lines(abs_path, from..to)

        return unless file_lines

        self.context_line = file_lines[padding]
        self.pre_context  = file_lines.first(padding)
        self.post_context = file_lines.last(padding)
      end
      # rubocop:enable Metrics/AbcSize

      private

      def read_lines(path, range)
        File.readlines(path)[range]
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
