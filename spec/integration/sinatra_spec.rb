# frozen_string_literal: true

require 'spec_helper'

if defined?(Sinatra)
  RSpec.describe 'Sinatra integration', :with_fake_server do
    include Rack::Test::Methods

    class FancyError < StandardError; end
    class BackwardsCompatibleLogger < Logger
      def write(*args)
        self.<<(*args)
      end
    end

    class SinatraTestApp < ::Sinatra::Base
      enable :logging
      disable :protection
      disable :show_exceptions

      use ElasticAPM::Middleware
      # use Rack::CommonLogger, BackwardsCompatibleLogger.new(STDOUT)
      use Rack::CommonLogger, BackwardsCompatibleLogger.new(nil)

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

      get '/error' do
        raise FancyError, 'Halp!'
      end
    end

    def app
      SinatraTestApp
    end

    before do
      ElasticAPM.start(
        app: SinatraTestApp,
        debug_transactions: true,
        flush_interval: nil
      )
    end

    after do
      ElasticAPM.stop
    end

    it 'knows Sinatra' do
      response = get '/'
      wait_for_requests_to_finish 1

      expect(response.body).to eq 'Yes!'

      service = FakeServer.requests.first['service']
      expect(service['name']).to eq 'SinatraTestApp'
      expect(service['framework']['name']).to eq 'Sinatra'
      expect(service['framework']['version'])
        .to match(/\d+\.\d+\.\d+(\.\d+)?/)
    end

    describe 'transactions' do
      it 'wraps requests in a transaction named after route' do
        get '/'
        wait_for_requests_to_finish 1

        expect(FakeServer.requests.length).to be 1
        request = FakeServer.requests.last
        expect(request['transactions'][0]['name']).to eq 'GET /'
      end

      it 'spans inline templates' do
        get '/inline'
        wait_for_requests_to_finish 1

        request = FakeServer.requests.last
        span = request['transactions'][0]['spans'][0]
        expect(span['name']).to eq 'Inline erb'
        expect(span['type']).to eq 'template.tilt'
      end

      it 'spans templates' do
        response = get '/tmpl'
        wait_for_requests_to_finish 1

        expect(response.body).to eq '1 2 3 hello you'

        request = FakeServer.requests.last
        span = request['transactions'][0]['spans'][0]
        expect(span['name']).to eq 'index'
        expect(span['type']).to eq 'template.tilt'
      end
    end

    describe 'errors' do
      it 'adds an exception handler and handles exceptions '\
        'AND posts transaction' do
        begin
          get '/error'
        rescue FancyError
        end

        wait_for_requests_to_finish 2

        expect(FakeServer.requests.length).to be 2

        exception = FakeServer.requests.last['errors'][0]['exception']
        expect(exception['type']).to eq 'FancyError'
      end
    end
  end
end
