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

      it 'starts the agent' do
        with_agent(klass: ElasticAPM::Sinatra, args: [SinatraTestApp]) do
          expect(ElasticAPM::Agent).to be_running
          expect(ElasticAPM.agent.config.service_name).to eq 'SinatraTestApp'
        end
      end

      context 'with config' do
        it 'sets the options' do
          with_agent(
            klass: ElasticAPM::Sinatra,
            args: [SinatraTestApp],
            service_name: 'my-app'
          ) do
            expect(ElasticAPM::Agent).to be_running
            expect(ElasticAPM.agent.config.service_name).to eq 'my-app'
          end
        end
      end
    end
  end
else
  puts '[INFO] Skipping Sinatra.start spec'
end
