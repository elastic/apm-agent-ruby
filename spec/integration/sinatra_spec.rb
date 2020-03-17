# frozen_string_literal: true

require 'spec_helper'

if defined?(Sinatra)
  enabled = true
else
  puts '[INFO] Skipping Sinatra spec'
end

if enabled
  RSpec.describe 'Sinatra integration', :mock_intake, :allow_running_agent do
    include Rack::Test::Methods

    def app
      SinatraTestApp
    end

    before(:all) do
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

      MockIntake.stub!
      ElasticAPM.start(app: SinatraTestApp, api_request_time: '250ms')
    end

    after(:all) do
      ElasticAPM.stop
    end

    it 'knows Sinatra' do
      response = get '/'

      wait_for metadatas: 1

      expect(response.body).to eq 'Yes!'

      service = MockIntake.metadatas.first['service']
      expect(service['name']).to eq 'SinatraTestApp'
      expect(service['framework']['name']).to eq 'Sinatra'
      expect(service['framework']['version'])
        .to match(/\d+\.\d+\.\d+(\.\d+)?/)
    end

    describe 'transactions' do
      it 'wraps requests in a transaction named after route' do
        get '/'

        wait_for transactions: 1

        expect(MockIntake.requests.length).to be 1
        transaction = MockIntake.transactions.first
        expect(transaction['name']).to eq 'GET /'
      end

      it 'spans inline templates' do
        get '/inline'

        wait_for transactions: 1, spans: 1

        span = MockIntake.spans.last
        expect(span['name']).to eq 'Inline erb'
        expect(span['type']).to eq 'template.tilt'
      end

      it 'spans templates' do
        response = get '/tmpl'

        wait_for transactions: 1, spans: 1

        expect(response.body).to eq '1 2 3 hello you'

        span = MockIntake.spans.last
        expect(span['name']).to eq 'index'
        expect(span['type']).to eq 'template.tilt'
      end
    end

    describe 'errors' do
      it 'adds an exception handler and posts transaction' do
        begin
          get '/error'
        rescue FancyError
        end

        wait_for errors: 1, transactions: 1

        error_request =
          MockIntake.errors.first
        exception = error_request['exception']
        expect(exception['type']).to eq 'FancyError'
      end
    end
  end
end
