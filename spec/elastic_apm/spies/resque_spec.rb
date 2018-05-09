# frozen_string_literal: true

require 'spec_helper'
require 'fakeredis'

require 'resque'

require 'elastic_apm/spies/resque'

module ElasticAPM
  class TestJob
    @queue = :default

    def self.perform
      ElasticAPM.span('Things') do
        'ok'
      end
    end
  end

  RSpec.describe 'Resque', :with_fake_server do
    shared_examples_for :resque_worker_with_apm do |fork|
      before do
        allow_any_instance_of(::Resque::Worker)
          .to receive(:fork_per_job?) { fork }
      end

      it 'instruments jobs once' do
        worker = Resque::Worker.new 'default'
        worker.prepare
        worker.log 'Starting'

        worker.startup
        Resque.enqueue(TestJob)

        worker.work_one_job

        expect(ElasticAPM.agent).to_not be_nil

        ElasticAPM.stop
        wait_for_requests_to_finish 1

        expect(FakeServer.requests.length).to be 1
      end
    end

    context 'environment allows forking' do
      it_behaves_like :resque_worker_with_apm, true
    end

    context 'environment does not allow forking' do
      it_behaves_like :resque_worker_with_apm, false
    end
  end
end
