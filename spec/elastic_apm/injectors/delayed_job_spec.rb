# frozen_string_literal: true

require 'spec_helper'

require 'elastic_apm/injectors/delayed_job'
require 'delayed_job'

class TransactionCapturingJob
  attr_accessor :transaction

  def perform
    self.transaction = ElasticAPM.current_transaction
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

module ElasticAPM
  RSpec.describe Injectors::DelayedJobInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['delayed/backend/base'] ||
        Injectors.installed['Delayed::Backend::Base']

      expect(registration.injector).to be_a described_class
    end

    describe 'tracing' do
      let(:enabled_injectors) { %w[delayed_job] }
      let(:config) { Config.new(enabled_injectors: enabled_injectors) }
      let(:mock_job) { TransactionCapturingJob.new }
      let(:invokable) { mock_job }

      before do
        Delayed::Worker.backend = MockJobBackend
        ElasticAPM.start
        Delayed::Job.new(invokable).invoke_job
      end

      after do
        ElasticAPM.stop
      end

      subject { mock_job.transaction }

      describe 'class-based job transaction' do
        it { is_expected.not_to be_nil }
        its(:name) { is_expected.to eq 'TransactionCapturingJob' }
        its(:type) { is_expected.to eq 'Delayed::Job' }
      end

      describe 'method-based job transaction' do
        let(:invokable) do
          Delayed::PerformableMethod.new(mock_job, :perform, [])
        end

        it { is_expected.not_to be_nil }
        its(:name) { is_expected.to eq 'TransactionCapturingJob#perform' }
        its(:type) { is_expected.to eq 'Delayed::Job' }
      end
    end
  end
end
