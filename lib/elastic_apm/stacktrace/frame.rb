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

      def build_context(context_line_count)
        return unless abs_path

        from = (lineno - context_line_count - 1)
        to = (lineno + context_line_count)
        file_lines = read_lines(abs_path, from..to)

        self.context_line = file_lines[context_line_count]
        self.pre_context  = file_lines.first(context_line_count)
        self.post_context = file_lines.last(context_line_count)
      end

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
