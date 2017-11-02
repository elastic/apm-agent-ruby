# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Util
    def self.nearest_minute(target = Time.now.utc)
      target - target.to_i % 60
    end

    def self.nanos(target = Time.now.utc)
      target.to_i * 1_000_000_000 + target.usec * 1_000
    end
  end
end
