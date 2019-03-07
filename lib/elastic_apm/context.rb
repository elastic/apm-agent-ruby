# frozen_string_literal: true

require 'elastic_apm/context/request'
require 'elastic_apm/context/request/socket'
require 'elastic_apm/context/request/url'
require 'elastic_apm/context/response'
require 'elastic_apm/context/user'

module ElasticAPM
  # @api private
  class Context
    def initialize(custom: {}, tags: {}, user: nil)
      @custom = custom
      @tags = tags
      @user = user || User.new
    end

    attr_accessor :request
    attr_accessor :response
    attr_accessor :user
    attr_reader :custom
    attr_reader :tags

    def empty?
      return false if tags.any?
      return false if custom.any?
      return false if user.any?
      return false if request || response

      true
    end
  end
end
