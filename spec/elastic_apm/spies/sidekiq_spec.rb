# frozen_string_literal: true

require 'fakeredis/rspec'
require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/testing'

require 'elastic_apm/spies/sidekiq'

begin
  require 'active_job'
rescue LoadError
end

module ElasticAPM
  RSpec.describe 'Spy: Sidekiq', :mock_intake do
    class TestingWorker
      include Sidekiq::Worker

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

    if defined?(ActiveJob)
      class ActiveJobbyJob < ActiveJob::Base
        self.queue_adapter = :sidekiq
        self.logger = nil # stay quiet

        def perform
          'ok'
        end
      end
    end

    before :all do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Spies::SidekiqSpy::Middleware
      end

      Sidekiq.logger = Logger.new(nil) # sssshh, we're testing
    end

    it 'starts when sidekiq processors do' do
      manager = Sidekiq::Manager.new concurrency: 1, queues: ['default']
      manager.start

      expect(ElasticAPM.agent).to_not be_nil

      manager.stop(::Process.clock_gettime(::Process::CLOCK_MONOTONIC))

      expect(ElasticAPM.agent).to be_nil
      expect(manager).to be_stopped
    end

    context 'with an agent' do
      let(:config) do
        Config.new(api_request_time: '20ms')
      end

      before { ElasticAPM.start(config) }
      after { ElasticAPM.stop }

      it 'instruments jobs' do
        Sidekiq::Testing.inline! do
          HardWorker.perform_async
        end

        wait_for transactions: 1

        transaction, = @mock_intake.transactions
        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ElasticAPM::HardWorker'
        expect(transaction['type']).to eq 'Sidekiq'
      end

      it 'reports errors' do
        Sidekiq::Testing.inline! do
          expect do
            ExplodingWorker.perform_async
          end.to raise_error(ZeroDivisionError)
        end

        ElasticAPM.stop

        wait_for transactions: 1, errors: 1

        transaction, = @mock_intake.transactions
        error, = @mock_intake.errors

        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ElasticAPM::ExplodingWorker'
        expect(transaction['type']).to eq 'Sidekiq'

        expect(error.dig('exception', 'type')).to eq 'ZeroDivisionError'
      end

      it 'knows the name of ActiveJob jobs', if: defined?(ActiveJob) do
        Sidekiq::Testing.inline! do
          ActiveJobbyJob.perform_later
        end

        wait_for transactions: 1

        transaction, = @mock_intake.transactions
        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ElasticAPM::ActiveJobbyJob'
      end
    end
  end
end
