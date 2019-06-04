# frozen_string_literal: true

module PlatformHelpers
  def darwin?
    ElasticAPM::Metrics.platform == :darwin
  end

  def linux?
    ElasticAPM::Metrics.platform == :linux
  end

  def self.jruby_92?
    defined?(JRUBY_VERSION) && JRUBY_VERSION =~ /^9\.2/
  end
end
