# frozen_string_literal: true

require 'elastic_apm/stacktrace/frame'
require 'elastic_apm/util/lru_cache'

module ElasticAPM
  # @api private
  class StacktraceBuilder
    JAVA_FORMAT = /^(.+)\.([^\.]+)\(([^\:]+)\:(\d+)\)$/.freeze
    RUBY_FORMAT = /^(.+?):(\d+)(?::in `(.+?)')?$/.freeze

    RUBY_VERS_REGEX = %r{ruby(/gems)?[-/](\d+\.)+\d}.freeze
    JRUBY_ORG_REGEX = %r{org/jruby}.freeze

    def initialize(config)
      @config = config
      @cache = Util::LruCache.new(2048, &method(:build_frame))
    end

    attr_reader :config

    def build(backtrace, type:)
      Stacktrace.new.tap do |s|
        s.frames = backtrace.map do |line|
          @cache[[line, type]]
        end
      end
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_frame(cache, keys)
      line, type = keys
      abs_path, lineno, function, _module_name = parse_line(line)

      frame = Stacktrace::Frame.new
      frame.abs_path = abs_path
      frame.filename = strip_load_path(abs_path)
      frame.function = function
      frame.lineno = lineno.to_i
      frame.library_frame = library_frame?(config, abs_path)

      line_count =
        context_lines_for(config, type, library_frame: frame.library_frame)
      frame.build_context line_count

      cache[[line, type]] = frame
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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
        return true if abs_path.start_with?(config.root_path + '/vendor')
        return false
      end

      return true if abs_path.match(RUBY_VERS_REGEX)
      return true if abs_path.match(JRUBY_ORG_REGEX)

      false
    end

    def strip_load_path(path)
      return nil if path.nil?

      prefix =
        $LOAD_PATH
        .map(&:to_s)
        .select { |s| path.start_with?(s) }
        .max_by(&:length)

      prefix ? path[prefix.chomp(File::SEPARATOR).length + 1..-1] : path
    end

    def context_lines_for(config, type, library_frame:)
      key = "source_lines_#{type}_#{library_frame ? 'library' : 'app'}_frames"
      config.send(key.to_sym)
    end
  end
end
