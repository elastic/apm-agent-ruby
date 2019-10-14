# frozen_string_literal: true

if defined?(Grape)
  require 'elastic_apm/grape'
  RSpec.describe Grape do
    describe '.start' do
      before :all do
        class GrapeTestApp < ::Grape::API
          use ElasticAPM::Middleware
        end
        ElasticAPM::Grape.start(GrapeTestApp, {})
      end

      it 'starts the agent' do
        expect(ElasticAPM::Agent).to be_running
      end

      after :all do
        ElasticAPM.stop
        Object.send(:remove_const, :GrapeTestApp)
      end
    end
  end
end
