# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Util
    def self.nearest_minute(target = Time.now.utc)
      target - target.to_i % 60
    end

    def self.micros(target = Time.now)
      utc = target.utc
      utc.to_i * 1_000_000 + utc.usec
    end

    def self.git_sha
      sha = `git rev-parse --verify HEAD 2>&1`.chomp
      $? && $?.success? ? sha : nil # rubocop:disable Style/SpecialGlobalVars
    end

    def self.hex_to_bits(str)
      str.hex.to_s(2).rjust(str.size * 4, '0')
    end

    def self.reverse_merge!(first, second)
      first.merge!(second) { |_, old, _| old }
    end
  end
end
