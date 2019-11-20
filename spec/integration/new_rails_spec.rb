# frozen_string_literal: true

require 'spec_helper'

if defined?(Rails)
  enabled = true
else
  puts '[INFO] Skipping Rails spec'
end

if enabled
  require 'action_controller/railtie'
  require 'action_mailer/railtie'

  RSpec.describe 'Rails integration' do
    include Rack::Test::Methods
    include_context 'request_parser'

    def app
      @app ||= Rails.application
    end

    after :all do
      ElasticAPM.stop
      ElasticAPM::Transport::Worker.adapter = nil
    end

    before :all do
      module RailsTestApp
        class Application < Rails::Application
          config.secret_key_base = '__secret_key_base'
          config.consider_all_requests_local = false
          config.eager_load = false

          config.elastic_apm.api_request_time = '200ms'
          config.elastic_apm.disable_start_message = true

          # Silence deprecation warning
          if defined?(ActionView::Railtie::NULL_OPTION)
            config.action_view.finalize_compiled_template_methods =
                ActionView::Railtie::NULL_OPTION
          end
          config.elastic_apm.capture_body = 'all'
          config.elastic_apm.pool_size = Concurrent.processor_count

          config.elastic_apm.log_path = 'spec/elastic_apm.log'
        end
      end

      class ApplicationController < ActionController::Base

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

      class TestAdapter < ElasticAPM::Transport::Connection
        def write(payload)
          RequestParser.catalog(JSON.parse(@metadata))
          RequestParser.catalog JSON.parse(payload)
        end
      end

      ElasticAPM::Transport::Worker.adapter = TestAdapter

      RailsTestApp::Application.initialize!
      RailsTestApp::Application.routes.draw do
        root to: 'application#index'
      end
    end

    context 'Service metadata', :allow_running_agent do
      it 'knows Rails' do
        responses = Array.new(10).map { get '/' }

        RequestParser.wait_for transactions: 10, spans: 20, timeout: 10

        expect(responses.last.body).to eq 'Yes!'
        expect(RequestParser.metadatas.length >= 1).to be true
        expect(RequestParser.transactions.length).to be 10

        service = RequestParser.metadatas.fetch(0)['service']
        expect(service['name']).to eq 'RailsTestApp'
        expect(service['framework']['name']).to eq 'Ruby on Rails'
        expect(service['framework']['version'])
            .to match(/\d+\.\d+\.\d+(\.\d+)?/)
      end
    end

    context 'log path', :allow_running_agent do
      it 'prepends Rails.root to log_path' do
        final_log_path = ElasticAPM.agent.config.log_path.to_s
        expect(final_log_path).to eq "#{Rails.root}/spec/elastic_apm.log"
      end
    end
  end
end
