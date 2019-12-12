# frozen_string_literal: true

require 'shoryuken'

require 'elastic_apm/spies/shoryuken'

begin
  require 'active_job'
rescue LoadError
end

module ElasticAPM
  RSpec.describe 'Spy: Shoryuken', :mock_intake do
    class TestingWorker
      include Shoryuken::Worker

      shoryuken_options queue: 'hello'

      def perform
        'ok'
      end
    end

    class HardWorker < TestingWorker; end
    class ExplodingWorker < TestingWorker
      def perform
        super
        1 / 0
      end
    end

    before :all do
      # Shoryuken.worker_executor = Shoryuken::Worker::InlineExecutor
    end

    it 'instruments jobs' do
      with_agent do
        HardWorker.perform_async('data')
      end

      wait_for transactions: 1

      transaction, = @mock_intake.transactions
      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::HardWorker'
      expect(transaction['type']).to eq 'Shoryuken'
    end

    it 'reports errors' do
      with_agent do
        expect do
          ExplodingWorker.perform_async('data')
        end.to raise_error(ZeroDivisionError)
      end

      wait_for transactions: 1, errors: 1

      transaction, = @mock_intake.transactions
      error, = @mock_intake.errors

      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::ExplodingWorker'
      expect(transaction['type']).to eq 'Shoryuken'

      expect(error.dig('exception', 'type')).to eq 'ZeroDivisionError'
    end

    context 'ActiveJob', if: defined?(ActiveJob) do
      before :all do
        # rubocop:disable Style/ClassAndModuleChildren
        class ::ActiveJobbyJob < ActiveJob::Base
          # rubocop:enable Style/ClassAndModuleChildren
          self.queue_adapter = :shoryuken
          self.logger = nil # stay quiet

          def perform
            'ok'
          end
        end
      end

      after :all do
        Object.send(:remove_const, :ActiveJobbyJob)
      end

      it 'knows the name of ActiveJob jobs', if: defined?(ActiveJob) do
        with_agent do
          ActiveJobbyJob.perform_later
        end

        wait_for transactions: 1

        transaction, = @mock_intake.transactions
        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ActiveJobbyJob'
      end
    end
  end
end
