# frozen_string_literal: true

require 'elastic_apm/version'

require 'elastic_apm/middleware'

module ElasticAPM
  def self.start; end

  def self.transaction(a, b); end
end
