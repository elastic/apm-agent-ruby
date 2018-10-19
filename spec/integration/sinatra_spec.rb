# frozen_string_literal: true

require 'spec_helper'

if defined?(Sinatra)
  RSpec.describe 'Sinatra integration', :mock_intake do
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
      use Rack::CommonLogger, BackwardsCompatibleLogger.new(nil)
      # use Rack::CommonLogger, BackwardsCompatibleLogger.new(STDOUT)

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

    before(:all) do
      ElasticAPM.start(app: SinatraTestApp)
    end

    after(:all) do
      ElasticAPM.stop
    end

    it 'knows Sinatra' do
      response = get '/'

      ElasticAPM.agent.flush
      wait_for_requests_to_finish 1

      expect(response.body).to eq 'Yes!'

      service = @mock_intake.metadatas.first['service']
      expect(service['name']).to eq 'SinatraTestApp'
      expect(service['framework']['name']).to eq 'Sinatra'
      expect(service['framework']['version'])
        .to match(/\d+\.\d+\.\d+(\.\d+)?/)
    end

    describe 'transactions' do
      it 'wraps requests in a transaction named after route' do
        get '/'

        ElasticAPM.agent.flush
        wait_for_requests_to_finish 1

        expect(@mock_intake.requests.length).to be 1
        transaction = @mock_intake.transactions.first
        expect(transaction['name']).to eq 'GET /'
      end

      it 'spans inline templates' do
        get '/inline'

        ElasticAPM.agent.flush
        wait_for_requests_to_finish 1

        span = @mock_intake.spans.last
        expect(span['name']).to eq 'Inline erb'
        expect(span['type']).to eq 'template.tilt'
      end

      it 'spans templates' do
        response = get '/tmpl'

        ElasticAPM.agent.flush
        wait_for_requests_to_finish 1

        expect(response.body).to eq '1 2 3 hello you'

        span = @mock_intake.spans.last
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

        ElasticAPM.agent.flush
        wait_for_requests_to_finish 1

        expect(@mock_intake.requests.length).to be 1

        error_request =
          @mock_intake.errors.first
        exception = error_request['exception']
        expect(exception['type']).to eq 'FancyError'
      end
    end
  end
else
  puts '[INFO] Skipping Sinatra spec'
end
