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

    # @api private
    class Frame
      attr_accessor(
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

    JAVA_FORMAT = /^(.+)\.([^\.]+)\(([^\:]+)\:(\d+)\)$/
    RUBY_FORMAT = /^(.+?):(\d+)(?::in `(.+?)')?$/

    def parse_line(line)
      ruby_match = line.match(RUBY_FORMAT)

      if ruby_match
        _, file, number, method = ruby_match.to_a
        file.sub!(/\.class$/, '.rb')
        module_name = nil
      else
        java_match = line.match(JAVA_FORMAT)
        _, module_name, method, file, number = java_match.to_a
      end

      [file, number, method, module_name]
    end

    def build_frame(_builder, line)
      abs_path, lineno, function, _module_name = parse_line(line)

      frame = Frame.new
      frame.abs_path = abs_path
      frame.filename = strip_load_path(abs_path)
      frame.function = function
      frame.lineno = lineno.to_i
      frame.build_context 3

      frame
    end

    def strip_load_path(path)
      return nil unless path

      prefix =
        $LOAD_PATH
        .map(&:to_s)
        .select { |s| path.start_with?(s) }
        .sort_by(&:length)
        .last

      return path unless prefix

      path[prefix.chomp(File::SEPARATOR).length + 1..-1]
    end
  end
end
