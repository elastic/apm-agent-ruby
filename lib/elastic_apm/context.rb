# frozen_string_literal: true

require 'elastic_apm/context/request'
require 'elastic_apm/context/request/socket'
require 'elastic_apm/context/request/url'
require 'elastic_apm/context/response'
require 'elastic_apm/context/user'

module ElasticAPM
  # @api private
  class Context
    attr_accessor :request, :response, :user
    attr_reader :custom, :tags

    def initialize(custom: {}, tags: {}, user: nil)
      @custom = custom
      @tags = tags
      @user = user || User.new
    end
  end
end
