# frozen_string_literal: true

require 'elastic_apm/stacktrace/frame'

module ElasticAPM
  # @api private
  class Stacktrace
    def initialize(exception)
      @exception = exception
    end

    attr_reader :frames

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
    end

    def to_a
      frames.map(&:to_h)
    end

    private

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
