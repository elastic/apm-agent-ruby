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

    def self.inspect_transaction(transaction)
      Inspector.new.transaction transaction
    end

    def self.git_sha
      sha = `git rev-parse --verify HEAD 2>&1`.chomp
      $CHILD_STATUS.success? ? sha : nil
    end
  end
end

require 'elastic_apm/util/inspector'
