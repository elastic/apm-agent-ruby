# frozen_string_literal: true

require 'elastic_apm/stacktrace/frame'
require 'elastic_apm/stacktrace/line_cache'

module ElasticAPM
  # @api private
  class Stacktrace
    GEMS_REGEX = %r{/gems/}

    def initialize(backtrace)
      @backtrace = backtrace
    end

    attr_reader :frames

    def self.build(config, backtrace)
      return nil unless backtrace

      stack = new(backtrace)
      stack.build_frames(config)
      stack
    end

    def build_frames(config)
      @frames = @backtrace.map do |line|
        build_frame(config, line)
      end
    end

    def length
      frames.length
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

    def build_frame(config, line)
      abs_path, lineno, function, _module_name = parse_line(line)

      frame = Frame.new
      frame.abs_path = abs_path
      frame.filename = strip_load_path(abs_path)
      frame.function = function
      frame.lineno = lineno.to_i
      frame.build_context 3
      frame.library_frame =
        !(abs_path && abs_path.start_with?(config.root_path))

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
