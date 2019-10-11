# frozen_string_literal: true

require 'spec_helper'

if defined?(Grape)
  require 'elastic_apm/grape'

  RSpec.describe 'Grape integration', :mock_intake do
    include Rack::Test::Methods

    let(:app) do
      Class.new(::Grape::API) do
        use ElasticAPM::Middleware

        get :pingpong do
          { :message => "Hello world!" }
        end

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
    end

    before(:all) do
      config = { api_request_time: '100ms',
                 capture_body: 'all',
                 pool_size: Concurrent.processor_count,
                 service_name: 'GrapeTestApp' }
      ElasticAPM::Grape.start(config)
    end

    context 'endpoint_run.grape'do
      it 'sets the transaction and span values' do
        get '/pingpong'
        wait_for transactions: 1, spans: 7

        span = @mock_intake.spans.find { |s| s['type'] == 'app.resource'}
        expect(span['name']).to eq('GET /pingpong')
        expect(span['type']).to eq('app.resource')

        transaction = @mock_intake.transactions.last
        expect(transaction['name']).to eq('GET /pingpong')
      end
    end

    context 'params specified' do
      it 'sets the transaction and span values' do
        get '/statuses/1'
        wait_for transactions: 1, spans: 7

        span = @mock_intake.spans.find { |s| s['type'] == 'app.resource'}
        expect(span['name']).to eq('GET /statuses/:id')
        expect(span['type']).to eq('app.resource')

        transaction = @mock_intake.transactions.last
        expect(transaction['name']).to eq('GET /statuses/:id')
      end
    end

    context 'with filters' do
      it 'sets the transaction and span values' do
        get '/statuses/1'
        wait_for transactions: 1, spans: 7

        span = @mock_intake.spans.find { |s| s['type'] == 'app.resource'}
        expect(span['name']).to eq('GET /statuses/:id')
        expect(span['type']).to eq('app.resource')

        filter_span = @mock_intake.spans.find { |s| s['type'] == 'filter.before'}
        expect(filter_span['name']).to eq('GET /statuses/:id')
        expect(filter_span['type']).to eq('filter.before')

        transaction = @mock_intake.transactions.last
        expect(transaction['name']).to eq('GET /statuses/:id')
      end
    end

    context 'with validators' do
      it 'sets the transaction and span values' do
        get '/statuses/1'
        wait_for transactions: 1, spans: 7

        span = @mock_intake.spans.find { |s| s['type'] == 'app.resource'}
        expect(span['name']).to eq('GET /statuses/:id')
        expect(span['type']).to eq('app.resource')

        filter_span = @mock_intake.spans.find { |s| s['type'] == 'validator'}
        expect(filter_span['name']).to eq('GET /statuses/:id')
        expect(filter_span['type']).to eq('validator')

        transaction = @mock_intake.transactions.last
        expect(transaction['name']).to eq('GET /statuses/:id')
      end
    end
  end
end
