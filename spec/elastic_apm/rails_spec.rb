# frozen_string_literal: true

if defined?(Rails)
  require 'elastic_apm/rails'
  RSpec.describe Rails do
    describe '.start' do
      before :all do
        ElasticAPM::Rails.start({})
      end

      it 'starts the agent' do
        expect(ElasticAPM::Agent).to be_running
      end

      it 'registers the ActionDispatchSpy' do
        expect(ElasticAPM::Agent).to be_running
      end

      after :all do
        ElasticAPM.stop
      end
    end

    describe 'Rails console' do
      before :all do
        module Rails
          class Console; end
        end

        ElasticAPM::Rails.start({})
      end

      after :all do
        ElasticAPM.stop
        Rails.send(:remove_const, :Console)
      end

      it "doesn't start when console" do
        expect(ElasticAPM.agent).to be nil
      end
    end
  end
end
