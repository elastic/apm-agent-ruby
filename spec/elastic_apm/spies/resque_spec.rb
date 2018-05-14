# frozen_string_literal: true

require 'spec_helper'
require 'fakeredis'

require 'resque'

require 'elastic_apm/spies/resque'

begin
  require 'active_job'
rescue LoadError
end

module ElasticAPM
  class TestJob
    @queue = :default

    def self.perform
      ElasticAPM.current_transaction.span('Things') do |_s|
        sleep 0.1
      end

      'ok'
    end
  end

  if defined?(ActiveJob)
    class ActiveJobbyJob < ActiveJob::Base
      def perform
        ElasticAPM.span('Things') { 'ok' }
      end
    end
  end

  RSpec.describe 'Resque', :with_fake_server do
    let!(:worker) do
      worker = Resque::Worker.new 'default'
      worker.prepare
      worker.startup
      worker
    end

    shared_examples_for :a_resque_instrumentation do
      it 'instruments jobs once' do
        Resque.enqueue(TestJob)

        work_one_job_and_wait_for_request

        expect(FakeServer.requests.length).to be 1
        payload, = FakeServer.requests.first['transactions']
        expect(payload['name']).to eq 'ElasticAPM::TestJob'
        expect(payload.dig('context', 'tags')).to eq('queue' => 'default')
        # puts '-' * 80
        # pp payload
        expect(payload['spans'].length).to eq 1
      end

      context 'inside ActiveJob', if: defined?(ActiveJob) do
        around do |example|
          adapter = ActiveJob::Base.queue_adapter
          logger = ActiveJob::Base.logger
          ActiveJob::Base.queue_adapter = :resque
          ActiveJob::Base.logger = nil
          example.run
          ActiveJob::Base.queue_adapter = adapter
          ActiveJob::Base.logger = logger
        end

        it 'knows original name' do
          ActiveJobbyJob.perform_later

          work_one_job_and_wait_for_request

          expect(FakeServer.requests.length).to be 1
          payload, = FakeServer.requests.first['transactions']
          expect(payload['name']).to eq 'ElasticAPM::ActiveJobbyJob'
        end
      end
    end

    def work_one_job_and_wait_for_request
      worker.work_one_job

      expect(ElasticAPM.agent).to_not be_nil

      ElasticAPM.stop
      wait_for_requests_to_finish 1
    end

    context 'environment allows forking' do
      it_behaves_like :a_resque_instrumentation
    end

    context 'environment disallows forking' do
      before do
        allow_any_instance_of(::Resque::Worker)
          .to receive(:fork_per_job?) { false }
      end

      it_behaves_like :a_resque_instrumentation
    end
  end
end
