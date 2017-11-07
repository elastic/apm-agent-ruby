# frozen_string_literal: true

require 'spec_helper'

require 'rails'
require 'action_controller/railtie'
require 'elastic_apm/integration/railtie'

RSpec.describe 'Rails integration' do
  include Rack::Test::Methods

  def boot
    TestApp.initialize!
    TestApp.routes.draw do
      root to: 'pages#index'
    end
  end

  before :all do
    class TestApp < Rails::Application
      config.secret_key_base = '__secret_key_base'

      config.logger = Logger.new(nil)
      config.logger.level = Logger::DEBUG

      config.eager_load = false
    end

    class PagesController < ActionController::Base
      def index
        render plain: 'Yes!'
      end
    end

    boot
  end

  after :all do
    %i[TestApp PagesController].each do |const|
      Object.send(:remove_const, const)
    end

    Rails.application = nil
  end

  def app
    @app ||= Rails.application
  end

  it 'traces action and posts it', :allow_api_requests, :mock_time do
    ElasticAPM.agent.config.transaction_send_interval = nil

    response = get '/'

    ElasticAPM.stop

    # sleep 1
    expect(response.body).to eq 'Yes!'
    expect(WebMock).to have_requested(:post, %r{/v1/transactions}).with(
      body: {
        transactions: [
          {
            id: '945254c5-67a5-417e-8a4e-aa29efcbfb79',
            name: 'Rack',
            type: 'request',
            result: nil,
            duration: 0,
            timestamp: '1992-01-01T01:00:00.000+01:00'
          }
        ]
      }.to_json
    )
  end
  it 'works'
end
