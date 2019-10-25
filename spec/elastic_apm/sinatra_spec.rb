# frozen_string_literal: true

if defined?(Sinatra)
  RSpec.describe Sinatra do
    describe '.start', :intercept do
      before do
        class SinatraTestApp < ::Sinatra::Base
          use ElasticAPM::Middleware
        end
      end

      after do
        Object.send(:remove_const, :SinatraTestApp)
      end

      context 'with no overridden config settings' do
        it 'starts the agent' do
          begin
            ElasticAPM::Sinatra.start(SinatraTestApp)
            expect(ElasticAPM::Agent).to be_running
            expect(ElasticAPM.agent.config.options[:service_name].value)
              .to eq 'SinatraTestApp'
          ensure
            ElasticAPM.stop
          end
        end
      end

      context 'a config with settings' do
        it 'sets the options' do
          begin
            ElasticAPM::Sinatra.start(SinatraTestApp, service_name: 'my-app')
            expect(ElasticAPM::Agent).to be_running
            expect(ElasticAPM.agent.config.options[:service_name].value)
              .to eq 'my-app'
          ensure
            ElasticAPM.stop
          end
        end
      end
    end
  end
else
  puts '[INFO] Skipping Sinatra.start spec'
end
