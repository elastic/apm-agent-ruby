# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Util
    def self.nearest_minute(target = Time.now.utc)
      target - target.to_i % 60
    end

    def self.micros(target = Time.now.utc)
      target.to_i * 1_000_000 + target.usec
    end

    def self.git_sha
      sha = `git rev-parse --verify HEAD 2>&1`.chomp
      $? && $?.success? ? sha : nil # rubocop:disable Style/SpecialGlobalVars
    end
  end
end
