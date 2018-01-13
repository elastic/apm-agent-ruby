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
        return unless abs_path

        file_lines = [nil] + read_lines(abs_path)

        self.context_line = file_lines[lineno]
        self.pre_context =
          file_lines[(lineno - context_line_count - 1)...lineno]
        self.post_context =
          file_lines[(lineno + 1)..(lineno + context_line_count)]
      end
      # rubocop:enable Metrics/AbcSize

      private

      def read_lines(path)
        File.readlines(path)
      rescue Errno::ENOENT
        []
      end
    end
  end
end
