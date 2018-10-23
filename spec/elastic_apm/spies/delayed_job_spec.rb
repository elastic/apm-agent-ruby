# frozen_string_literal: true

begin
  require 'delayed_job'
  require 'delayed/performable_mailer' # or the Rails spec explodes
rescue LoadError
end

if defined?(Delayed::Backend)
  module ElasticAPM
    RSpec.describe 'Spy: DelayedJob', :intercept do
      class TestJob
        def perform
        end
      end

      class ExplodingJob
        def perform
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

      before { ElasticAPM.start }
      after { ElasticAPM.stop }

      it 'instruments class-based job transaction' do
        job = TestJob.new

        Delayed::Job.new(job).invoke_job

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq 'ElasticAPM::TestJob'
        expect(transaction.type).to eq 'Delayed::Job'
        expect(transaction.result).to eq 'success'
      end

      it 'instruments method-based job transaction' do
        job = TestJob.new
        invokable = Delayed::PerformableMethod.new(job, :perform, [])

        Delayed::Job.new(invokable).invoke_job

        transaction, = @intercepted.transactions
        expect(transaction.name)
          .to eq 'ElasticAPM::TestJob#perform'
        expect(transaction.type).to eq 'Delayed::Job'
        expect(transaction.result).to eq 'success'
      end

      it 'reports errors' do
        job = ExplodingJob.new

        expect do
          Delayed::Job.new(job).invoke_job
        end.to raise_error(ZeroDivisionError)

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq 'ElasticAPM::ExplodingJob'
        expect(transaction.type).to eq 'Delayed::Job'
        expect(transaction.result).to eq 'error'

        error, = @intercepted.errors
        expect(error.exception.type).to eq 'ZeroDivisionError'
      end
    end
  end
end
