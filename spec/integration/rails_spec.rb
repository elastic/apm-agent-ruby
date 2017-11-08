# frozen_string_literal: true

require 'spec_helper'

require 'rails'
require 'action_controller/railtie'

RSpec.describe 'Rails integration' do
  include Rack::Test::Methods

  def boot
    TestApp.initialize!
    TestApp.routes.draw do
      root to: 'pages#index'
    end
  end

  def app
    @app ||= Rails.application
  end

  before :all do
    class TestApp < Rails::Application
      config.secret_key_base = '__secret_key_base'

      config.logger = Logger.new(STDOUT)
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

  before { allow(SecureRandom).to receive(:uuid) { '_RANDOM' } }

  it 'traces action and posts it', :allow_api_requests do
    ElasticAPM.agent.config.tap do |config|
      config.transaction_send_interval = nil
      config.debug_transactions = true
    end

    response = get '/'

    # sleep 1
    expect(response.body).to eq 'Yes!'
    expect(WebMock).to have_requested(:post, %r{/v1/transactions})

    ElasticAPM.stop
  end
end
