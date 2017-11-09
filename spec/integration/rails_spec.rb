# frozen_string_literal: true

require 'spec_helper'

require 'rails'
require 'action_controller/railtie'
require 'elastic_apm/railtie'

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

      config.logger = Logger.new(ENV['DEBUG'].to_i == 1 ? STDOUT : nil)
      config.logger.level = Logger::DEBUG

      config.eager_load = false

      # post transactions right away
      config.elastic_apm.transaction_send_interval = nil

      config.elastic_apm.debug_transactions = true
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
    # test config from Rails.app.config
    expect(ElasticAPM.agent.config.debug_transactions).to be true

    response = get '/'

    # sleep 1
    expect(response.body).to eq 'Yes!'
    expect(WebMock).to have_requested(:post, %r{/v1/transactions})
  end

  after do
    ElasticAPM.stop
  end
end
