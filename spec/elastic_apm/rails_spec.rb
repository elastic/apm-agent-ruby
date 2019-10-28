# frozen_string_literal: true

if defined?(Rails)
  RSpec.describe Rails, :intercept do
    describe '.start' do
      it 'starts the agent' do
        begin
          ElasticAPM::Rails.start({})
          expect(ElasticAPM::Agent).to be_running
        ensure
          ElasticAPM.stop
        end
      end
    end

    describe 'Rails console' do
      before do
        module Rails
          class Console; end
        end
      end

      after { Rails.send(:remove_const, :Console) }

      it "doesn't start when console" do
        begin
          ElasticAPM::Rails.start({})
          expect(ElasticAPM.agent).to be nil
          expect(ElasticAPM).to_not be_running
        ensure
          ElasticAPM.stop
        end
      end
    end
  end
end
