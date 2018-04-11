# frozen_string_literal: true

require 'spec_helper'

require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/testing'

require 'elastic_apm/injectors/sidekiq'

begin
  require 'active_job'
rescue LoadError
end

module ElasticAPM
  RSpec.describe Injectors::SidekiqInjector, :with_fake_server do
    module SaveTransaction
      def self.included(kls)
        class << kls
          attr_accessor :last_transaction
        end
      end

      def set_current_transaction!
        self.class.last_transaction = ElasticAPM.current_transaction
      end
    end

    class TestingWorker
      include Sidekiq::Worker
      include SaveTransaction

      def perform
        set_current_transaction!
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
        include SaveTransaction
        self.queue_adapter = :sidekiq
        self.logger = nil # stay quiet

        def perform
          set_current_transaction!
        end
      end
    end

    before :all do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Injectors::SidekiqInjector::Middleware
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

        transaction = HardWorker.last_transaction
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

        transaction = ExplodingWorker.last_transaction
        expect(transaction).to_not be_nil
        expect(transaction.name).to eq 'ElasticAPM::ExplodingWorker'
        expect(transaction.type).to eq 'Sidekiq'

        wait_for_requests_to_finish 1
        expect(FakeServer.requests.length).to be 1

        payload, = FakeServer.requests.last
        type = payload.dig('errors', 0, 'exception', 'type')
        expect(type).to eq 'ZeroDivisionError'
      end

      it 'knows the name of ActiveJob jobs', if: defined?(ActiveJob) do
        Sidekiq::Testing.inline! do
          ActiveJobbyJob.perform_later
        end

        transaction = ActiveJobbyJob.last_transaction
        expect(transaction).to_not be_nil
        expect(transaction.name).to eq 'ElasticAPM::ActiveJobbyJob'
      end
    end
  end
end
