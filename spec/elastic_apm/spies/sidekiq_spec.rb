# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/testing'

require 'elastic_apm/spies/sidekiq'

begin
  require 'active_job'
rescue LoadError
end

module ElasticAPM
  RSpec.describe 'Spy: Sidekiq', :intercept do
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

      manager.stop(Time.now)

      expect(ElasticAPM.agent).to be_nil
      expect(manager).to be_stopped
    end

    context 'with an agent' do
      before { ElasticAPM.start }
      after { ElasticAPM.stop }

      it 'instruments jobs' do
        Sidekiq::Testing.inline! do
          HardWorker.perform_async
        end

        transaction, = @intercepted.transactions
        expect(transaction).to_not be_nil
        expect(transaction.name).to eq 'ElasticAPM::HardWorker'
        expect(transaction.type).to eq 'Sidekiq'
      end

      it 'reports errors' do
        Sidekiq::Testing.inline! do
          expect do
            ExplodingWorker.perform_async
          end.to raise_error(ZeroDivisionError)
        end

        ElasticAPM.stop

        transaction, = @intercepted.transactions
        error, = @intercepted.errors

        expect(transaction).to_not be_nil
        expect(transaction.name).to eq 'ElasticAPM::ExplodingWorker'
        expect(transaction.type).to eq 'Sidekiq'

        expect(error.exception.type).to eq 'ZeroDivisionError'
      end

      it 'knows the name of ActiveJob jobs', if: defined?(ActiveJob) do
        Sidekiq::Testing.inline! do
          ActiveJobbyJob.perform_later
        end

        transaction, = @intercepted.transactions
        expect(transaction).to_not be_nil
        expect(transaction.name).to eq 'ElasticAPM::ActiveJobbyJob'
      end
    end
  end
end
