# frozen_string_literal: true

module ElasticAPM
  class Metadata
    # @api private
    class ProcessInfo
      def initialize
        @argv = ARGV
        @pid = $PID || Process.pid
        @title = $PROGRAM_NAME
      end

      attr_reader :argv, :pid, :title
    end
  end
end
