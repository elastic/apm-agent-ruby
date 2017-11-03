# frozen_string_literal: true

module ElasticAPM
  # @api private
  # TODO
  class Config
    DEFAULTS = {
      logger: Logger.new(STDOUT),
      server: 'http://localhost:8200',

      transaction_send_interval: 60
    }.freeze

    attr_accessor :logger
    attr_accessor :server

    attr_accessor :transaction_send_interval

    def initialize(options = {})
      DEFAULTS.merge(options).each do |key, value|
        send("#{key}=", value)
      end

      return unless block_given?

      yield self
    end
  end
end
