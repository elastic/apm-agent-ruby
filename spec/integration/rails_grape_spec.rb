# frozen_string_literal: true

require 'spec_helper'

if (defined?(Rails) && defined?(Grape))
  require 'action_controller/railtie'

  RSpec.describe 'Rails and Grape integration', :mock_intake do
    include Rack::Test::Methods

    def app
      @app ||= Rails.application
    end

    before :all do
      class RailsGrapeTestApp < Rails::Application
        config.logger = Logger.new(nil)
        config.logger.level = Logger::DEBUG
        config.eager_load = false

        config.elastic_apm.api_request_time = '100ms'
        config.elastic_apm.pool_size = Concurrent.processor_count
        config.elastic_apm.service_name = 'RailsGrapeTestApp'
        config.elastic_apm.logger = config.logger
      end

      class RailsGrapeAppController < ActionController::Base
        def index
          render_ok
        end

        private

        def render_ok
          if Rails.version.start_with?('4')
            render text: 'Yes!'
          else
            render plain: 'Yes!'
          end
        end
      end

      class GrapeTestApp < ::Grape::API
        use ElasticAPM::Middleware
        resource :statuses do
          desc 'Return a status.'
          params do
            requires :id, type: Integer, desc: 'Status id.'
          end
          route_param :id do
            get do
              { status: params[:id] }
            end
          end
        end
      end

      MockIntake.instance.stub!

      RailsGrapeTestApp.initialize!
      RailsGrapeTestApp.routes.draw do
        get '/', to: 'rails_grape_app#index'
        mount GrapeTestApp, at: '/api'
      end
    end

    after :all do
      %i[RailsGrapeTestApp RailsGrapeAppController].each do |const|
        Object.send(:remove_const, const)
      end
      ElasticAPM.stop
      Rails.application = nil
    end

    context 'grape endpoint' do
      it 'sets the framework name on the event' do
        get '/api/statuses/1'

        wait_for transactions: 1, spans: 1
        context = @mock_intake.transactions.fetch(0)['context']
        expect(context['service']['framework']['name']).to eq('Grape')
        expect(context['service']['framework']['version']).to eq(::Grape::VERSION)
      end
    end

    context 'rails endpoint' do
      it 'does not set the framework name on the event' do
        get '/'

        wait_for transactions: 1, spans: 2
        context = @mock_intake.transactions.fetch(0)['context']
        expect(context['service']).to be_nil
      end
    end
  end
else
  puts '[INFO] Skipping Rails/Grape spec'
end
