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
  end
end

require 'elastic_apm/util/inspector'
require 'elastic_apm/util/inspector'
