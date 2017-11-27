# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Stacktrace
    def initialize(exception)
      @exception = exception
      @culprit = nil
    end

    attr_reader :frames, :culprit

    def self.build(builder, exception)
      return nil unless exception.backtrace

      stack = new(exception)
      stack.build_frames(builder)
      stack
    end

    def build_frames(builder)
      @frames = @exception.backtrace.reverse.map do |line|
        build_frame(builder, line)
      end

      @culprit = @frames.last.function
    end

    def to_h
      { frames: frames.map(&:to_json) }
    end

    private

    Frame = Struct.new(
      :abs_path,
      :filename,
      :function,
      :vars,
      :pre_context,
      :context_line,
      :post_context,
      :in_app,
      :lineno,
      :module,
      :colno
    )

    LINE_REGEX = /^(.+?):(\d+)(?::in `(.+?)')?$/

    # rubocop:disable Metrics/MethodLength
    def build_frame(_builder, line)
      _, abs_path, lineno, function = line.match(LINE_REGEX).to_a

      lineno = lineno.to_i
      filename = strip_load_path(abs_path)
      pre, actual, post = get_context(abs_path, lineno, 3)

      Frame.new(
        abs_path,
        filename,
        function,
        nil,
        pre,
        actual,
        post,
        nil,
        lineno,
        nil,
        nil
      )
    end
    # rubocop:enable Metrics/MethodLength

    def strip_load_path(path)
      prefix =
        $LOAD_PATH
        .map(&:to_s)
        .select { |s| path.start_with?(s) }
        .sort_by(&:length).last

      return path unless prefix

      path[prefix.chomp(File::SEPARATOR).length + 1..-1]
    end

    def get_context(path, lineno, context_line_count)
      file_lines = [nil] + File.readlines(path)

      pre = file_lines[(lineno - context_line_count - 1)...lineno]
      line = file_lines[lineno]
      post = file_lines[(lineno + 1)..(lineno + context_line_count)]

      [pre, line, post]
    end
  end
end
