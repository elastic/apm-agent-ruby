# frozen_string_literal: true

require 'spec_helper'

if defined?(Sinatra)
  RSpec.describe 'Sinatra integration' do
    include Rack::Test::Methods

    class SinatraTestApp < ::Sinatra::Base
      disable :show_exceptions
      use ElasticAPM::Middleware

      get '/' do
        'Yes!'
      end

      get '/inline' do
        erb 'Inline <%= "t" * 3 %>emplate'
      end

      template :index do
        '<%= (1..3).to_a.join(" ") %> hello <%= @name %>'
      end

      get '/tmpl' do
        @name = 'you'
        erb :index
      end
    end

    def app
      SinatraTestApp
    end

    before do
      config = ElasticAPM::Config.new(
        log_level: Logger::DEBUG,
        log_path: nil, # disable logging
        debug_transactions: true,
        transaction_send_interval: nil,
        enabled_injectors: %w[sinatra]
      )

      ElasticAPM.start config
    end

    after do
      ElasticAPM.stop
    end

    it 'wraps requests in a transaction named after route', :with_fake_server do
      response = get '/'
      wait_for_requests_to_finish 1

      expect(response.body).to eq 'Yes!'
      expect(FakeServer.requests.length).to be 1

      request = FakeServer.requests.last
      expect(request.dig('transactions', 0, 'name')).to eq 'GET /'
    end

    it 'spans inline templates', :with_fake_server do
      get '/inline'
      wait_for_requests_to_finish 1

      request = FakeServer.requests.last
      span = request.dig('transactions', 0, 'spans', 0)
      expect(span['name']).to eq 'Inline erb'
      expect(span['type']).to eq 'template.tilt'
    end

    it 'spans templates', :with_fake_server do
      response = get '/tmpl'
      wait_for_requests_to_finish 1

      expect(response.body).to eq '1 2 3 hello you'

      request = FakeServer.requests.last
      span = request.dig('transactions', 0, 'spans', 0)
      expect(span['name']).to eq 'index'
      expect(span['type']).to eq 'template.tilt'
    end
  end
end
