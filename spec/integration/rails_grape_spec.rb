# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails) && defined?(Grape)
  enabled = true
else
  puts '[INFO] Skipping Rails/Grape spec'
end

if enabled
  require 'action_controller/railtie'

  RSpec.describe 'Rails and Grape integration',
    :mock_intake, :allow_running_agent do
    include Rack::Test::Methods

    def app
      @app ||= Rails.application
    end

    before :all do
      class RailsGrapeTestApp < Rails::Application
        configure_rails_for_test

        config.secret_key_base = '__rails_grape'
        config.logger = Logger.new(nil)
        config.eager_load = false
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
      ElasticAPM.stop
    end

    context 'grape endpoint' do
      it 'sets the framework name on the event' do
        get '/api/statuses/1'

        wait_for transactions: 1, spans: 1
        context = @mock_intake.transactions.fetch(0)['context']
        expect(context['service']['framework']['name']).to eq('Grape')
        expect(context['service']['framework']['version'])
          .to eq(::Grape::VERSION)
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
end
