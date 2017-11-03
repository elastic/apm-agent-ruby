# frozen_string_literal: true

module ElasticAPM
  # @api private
  # TODO
  class Config
    DEFAULTS = {
      server: 'http://localhost:8200'
    }.freeze

    attr_accessor :server

    def initialize(options = {})
      DEFAULTS.merge(options).each do |key, value|
        send("#{key}=", value)
      end

      return unless block_given?

      yield self
    end
  end
end
