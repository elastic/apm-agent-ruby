# frozen_string_literal: true

require 'elastic_apm/context/request'
require 'elastic_apm/context/request/socket'
require 'elastic_apm/context/request/url'
require 'elastic_apm/context/response'
require 'elastic_apm/context/user'

module ElasticAPM
  # @api private
  class Context
    def initialize(custom: {}, labels: {}, user: nil, service: nil)
      @custom = custom
      @labels = labels
      @user = user || User.new
      @service = service
    end

    Service = Struct.new(:framework)
    Framework = Struct.new(:name, :version)

    attr_accessor :request
    attr_accessor :response
    attr_accessor :user
    attr_reader :custom
    attr_reader :labels
    attr_reader :service

    def empty?
      return false if labels.any?
      return false if custom.any?
      return false if user.any?
      return false if service
      return false if request || response

      true
    end

    def set_service(framework_name: nil, framework_version: nil)
      @service = Service.new(Framework.new(framework_name,
                                           framework_version))
    end
  end
end
