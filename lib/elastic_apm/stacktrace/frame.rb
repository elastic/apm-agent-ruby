# frozen_string_literal: true

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
        to = lineno + padding - 1
        file_lines = read_lines(abs_path, from..to)

        self.context_line = file_lines[padding]
        self.pre_context  = file_lines.first(padding)
        self.post_context = file_lines.last(padding)
      end
      # rubocop:enable Metrics/AbcSize

      private

      def read_lines(path, range)
        if (cached = LineCache.get(path, range))
          return cached
        end

        LineCache.set(path, range, File.readlines(path)[range])
      rescue Errno::ENOENT
        []
      end
    end
  end
end
