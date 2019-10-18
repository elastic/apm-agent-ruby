# frozen_string_literal: true

if defined?(Grape)
  RSpec.describe Grape do
    describe '.start' do
      before do
        class GrapeTestApp < ::Grape::API
          use ElasticAPM::Middleware
        end
        ElasticAPM::Grape.start(GrapeTestApp, config)
      end

      after do
        ElasticAPM.stop
        Object.send(:remove_const, :GrapeTestApp)
      end

      context 'with no overridden config settings' do
        let(:config) { {} }
        it 'starts the agent' do
          expect(ElasticAPM::Agent).to be_running
        end
      end

      context 'a config with settings' do
        let(:config) { { service_name: 'Other Name' } }

        it 'sets the options' do
          expect(ElasticAPM.agent.config.options[:service_name].value)
            .to eq('Other Name')
        end
      end
    end
  end
end
