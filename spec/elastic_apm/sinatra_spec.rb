# frozen_string_literal: true

if defined?(Sinatra)
  require 'elastic_apm/sinatra'
  RSpec.describe Sinatra do
    describe '.start' do
      before do
        class SinatraTestApp < ::Sinatra::Base
          use ElasticAPM::Middleware
        end
        ElasticAPM::Sinatra.start(SinatraTestApp, config)
      end

      after do
        ElasticAPM.stop
        Object.send(:remove_const, :SinatraTestApp)
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
else
  puts '[INFO] Skipping Sinatra.start spec'
end
