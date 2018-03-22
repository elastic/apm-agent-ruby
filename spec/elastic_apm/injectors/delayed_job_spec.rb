# frozen_string_literal: true

require 'spec_helper'

require 'elastic_apm/injectors/delayed_job'

begin
  require 'delayed_job'
rescue LoadError
end

if defined?(Delayed::Backend)
  module ElasticAPM
    RSpec.describe Injectors::DelayedJobInjector do
      it 'registers' do
        registration =
          Injectors.require_hooks['delayed/backend/base'] ||
          Injectors.installed['Delayed::Backend::Base']

        expect(registration.injector).to be_a described_class
      end

      describe 'transactions' do
        class TransactionCapturingJob
          attr_accessor :transaction

          def perform
            self.transaction = ElasticAPM.current_transaction
          end
        end

        class ExplodingJob
          attr_accessor :transaction

          def perform
            self.transaction = ElasticAPM.current_transaction

            1 / 0
          end
        end

        class MockJobBackend
          include Delayed::Backend::Base

          def initialize(job)
            @job = job
          end

          def payload_object
            @job
          end
        end

        before :all do
          Delayed::Worker.backend = MockJobBackend
        end

        before do
          ElasticAPM.start Config.new(enabled_injectors: %w[delayed_job])
        end

        after do
          ElasticAPM.stop
        end

        it 'instruments class-based job transaction' do
          job = TransactionCapturingJob.new

          Delayed::Job.new(job).invoke_job

          transaction = job.transaction
          expect(transaction.name).to eq 'ElasticAPM::TransactionCapturingJob'
          expect(transaction.type).to eq 'Delayed::Job'
          expect(transaction.result).to eq 'success'
        end

        it 'instruments method-based job transaction' do
          job = TransactionCapturingJob.new
          invokable = Delayed::PerformableMethod.new(job, :perform, [])

          Delayed::Job.new(invokable).invoke_job

          transaction = job.transaction
          expect(transaction.name)
            .to eq 'ElasticAPM::TransactionCapturingJob#perform'
          expect(transaction.type).to eq 'Delayed::Job'
          expect(transaction.result).to eq 'success'
        end

        it 'reports errors', :with_fake_server do
          job = ExplodingJob.new

          expect do
            Delayed::Job.new(job).invoke_job
          end.to raise_error(ZeroDivisionError)

          transaction = job.transaction
          expect(transaction.name).to eq 'ElasticAPM::ExplodingJob'
          expect(transaction.type).to eq 'Delayed::Job'
          expect(transaction.result).to eq 'error'

          wait_for_requests_to_finish 1
          expect(FakeServer.requests.length).to be 1
          type = FakeServer.requests.first.dig('errors', 0, 'exception', 'type')
          expect(type).to eq 'ZeroDivisionError'
        end
      end
    end
  end
end
