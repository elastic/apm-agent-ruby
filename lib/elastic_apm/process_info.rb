# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ProcessInfo
    def initialize(config)
      @config = config
    end

    def build
      {
        argv: ARGV,
        pid: $PID,
        title: $PROGRAM_NAME
      }
    end

    def self.build(config)
      new(config).build
    end
  end
end
