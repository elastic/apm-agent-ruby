# frozen_string_literal: true

require 'elastic_apm/context/request'
require 'elastic_apm/context/request/socket'
require 'elastic_apm/context/request/url'
require 'elastic_apm/context/response'
require 'elastic_apm/context/user'

module ElasticAPM
  # @api private
  class Context
    def initialize(custom: {}, labels: {}, user: nil)
      @custom = custom
      @labels = labels
      @user = user || User.new
    end

    attr_accessor :request
    attr_accessor :response
    attr_accessor :user
    attr_reader :custom
    attr_reader :labels

    def empty?
      return false if labels.any?
      return false if custom.any?
      return false if user.any?
      return false if request || response

      true
    end
  end
end
