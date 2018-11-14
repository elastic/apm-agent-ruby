# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'elastic-apm'

class App
  module Helpers
    def with_app(config = {})
      app = App.new(config)
      app.start
      result = yield app
      app.stop

      result
    end

  end

  def initialize(config = {})
    @config = ElasticAPM::Config.new(
      {
        environment: 'bench',
        disable_send: true
      }.merge(config)
    )
    # @serializer = ElasticAPM::Serializers::Transactions.new(@config)
    @mock_env = Rack::MockRequest.env_for('/')
  end

  attr_reader :mock_env, :serializer

  def start
    @agent = ElasticAPM.start(@config)
  end

  def stop
    ElasticAPM.stop
  end
end
