# frozen_string_literal: true

require 'elastic_apm/stacktrace/frame'
require 'elastic_apm/stacktrace/line_cache'

module ElasticAPM
  # @api private
  class Stacktrace
    JAVA_FORMAT = /^(.+)\.([^\.]+)\(([^\:]+)\:(\d+)\)$/
    RUBY_FORMAT = /^(.+?):(\d+)(?::in `(.+?)')?$/

    RUBY_VERS_REGEX = %r{ruby[-/](\d+\.)+\d}
    JRUBY_ORG_REGEX = %r{org/jruby}

    def initialize(backtrace)
      @backtrace = backtrace
    end

    attr_reader :frames

    def self.build(config, backtrace, type)
      return nil unless backtrace

      stack = new(backtrace)
      stack.build_frames(config, type)
      stack
    end

    def build_frames(config, type)
      @frames = @backtrace.map do |line|
        build_frame(config, line, type)
      end
    end

    def length
      frames.length
    end

    def to_a
      frames.map(&:to_h)
    end

    private

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

    def library_frame?(config, abs_path)
      return false unless abs_path

      if abs_path.start_with?(config.root_path)
        return true if abs_path.match(config.root_path + '/vendor')
        return false
      end

      return true if abs_path.match(RUBY_VERS_REGEX)
      return true if abs_path.match(JRUBY_ORG_REGEX)

      false
    end

    # rubocop:disable Metrics/MethodLength
    def build_frame(config, line, type)
      abs_path, lineno, function, _module_name = parse_line(line)

      frame = Frame.new
      frame.abs_path = abs_path
      frame.filename = strip_load_path(abs_path)
      frame.function = function
      frame.lineno = lineno.to_i
      frame.library_frame = library_frame?(config, abs_path)

      line_count =
        context_lines_for(config, type, library_frame: frame.library_frame)
      frame.build_context line_count

      frame
    end
    # rubocop:enable Metrics/MethodLength

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

    def context_lines_for(config, type, library_frame:)
      key = "source_lines_#{type}_#{library_frame ? 'library' : 'app'}_frames"
      config.send(key.to_sym)
    end
  end
end
