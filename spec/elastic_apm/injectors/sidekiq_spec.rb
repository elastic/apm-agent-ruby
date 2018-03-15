# frozen_string_literal: true

require 'spec_helper'

require 'elastic_apm/injectors/sidekiq'
require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/testing'

module ElasticAPM
  RSpec.describe Injectors::SidekiqInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['sidekiq'] ||
        Injectors.installed['Sidekiq']

      expect(registration.injector).to be_a described_class
    end

    class TestingWorker
      include Sidekiq::Worker

      class << self
        attr_accessor :last_transaction
      end

      def perform
        self.class.last_transaction = ElasticAPM.current_transaction
      end
    end

    class HardWorker < TestingWorker
    end

    class ExplodingWorker < TestingWorker
      def perform
        super
        1 / 0
      end
    end

    before :all do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Injectors::SidekiqInjector::Middleware
      end
    end

    it 'instruments jobs' do
      ElasticAPM.start(enabled_injectors: %w[sidekiq])

      Sidekiq::Testing.inline! do
        HardWorker.perform_async
      end

      transaction = HardWorker.last_transaction
      expect(transaction).to_not be_nil
      expect(transaction.name).to eq 'ElasticAPM::HardWorker'
      expect(transaction.type).to eq 'Sidekiq'

      ElasticAPM.stop
    end

    it 'reports errors', :with_fake_server do
      ElasticAPM.start(enabled_injectors: %w[sidekiq])

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

      ElasticAPM.stop
    end

    it 'starts when sidekiq processors do' do
      manager = Sidekiq::Manager.new concurrency: 1, queues: ['default']
      manager.start

      expect(ElasticAPM.agent).to_not be_nil

      manager.quiet

      expect(ElasticAPM.agent).to be_nil
      expect(manager).to be_stopped
    end
  end
end
